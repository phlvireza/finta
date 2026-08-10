import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The queries behind a budget's detail screen.
///
/// `DatabaseHelper` is a real singleton bound to the on-disk database path,
/// so `TransactionRepository` isn't test-injectable — as in
/// account_balance_test.dart, these tests pin the exact `WHERE` clauses the
/// repository uses against an in-memory database.
///
/// The invariant that matters most is the last group: `getCategoriesByDateRange`
/// must list precisely the rows `getCategoriesSumByDateRange` adds up. The
/// detail screen prints the sum in its header and the rows underneath it, so
/// any drift between the two clauses reads to the user as a lost transaction.
Future<Database> _openTestDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    ':memory:',
    options: OpenDatabaseOptions(version: 1),
  );
  await db.execute('''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      categoryId TEXT,
      accountId TEXT NOT NULL,
      isTransfer INTEGER NOT NULL DEFAULT 0,
      date TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');
  return db;
}

// --- The repository's clauses, verbatim. ---

Future<List<Map<String, Object?>>> categoriesByDateRange(
  Database db,
  List<String> categoryIds,
  DateTime start,
  DateTime end,
) async {
  if (categoryIds.isEmpty) return [];
  final placeholders = List.filled(categoryIds.length, '?').join(',');
  return db.query(
    'transactions',
    where: 'categoryId IN ($placeholders) AND date >= ? AND date <= ? AND isTransfer = 0',
    whereArgs: [
      ...categoryIds,
      start.toIso8601String().substring(0, 10),
      end.toIso8601String().substring(0, 10),
    ],
    orderBy: 'date DESC, createdAt DESC',
  );
}

Future<double> categoriesSumByDateRange(
  Database db,
  List<String> categoryIds,
  DateTime start,
  DateTime end,
) async {
  if (categoryIds.isEmpty) return 0;
  final placeholders = List.filled(categoryIds.length, '?').join(',');
  final result = await db.rawQuery(
    'SELECT COALESCE(SUM(amount), 0) as total FROM transactions '
    'WHERE categoryId IN ($placeholders) AND date >= ? AND date <= ? AND isTransfer = 0',
    [
      ...categoryIds,
      start.toIso8601String().substring(0, 10),
      end.toIso8601String().substring(0, 10),
    ],
  );
  return (result.first['total'] as num).toDouble();
}

Future<List<Map<String, Object?>>> byTypeAndDateRange(
  Database db,
  String type,
  DateTime start,
  DateTime end,
) {
  return db.query(
    'transactions',
    where: 'type = ? AND date >= ? AND date <= ? AND isTransfer = 0',
    whereArgs: [
      type,
      start.toIso8601String().substring(0, 10),
      end.toIso8601String().substring(0, 10),
    ],
    orderBy: 'date DESC, createdAt DESC',
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  // A payday-anchored period, the shape BudgetStatus carries.
  final start = DateTime(2026, 3, 25);
  final end = DateTime(2026, 4, 24);

  const food = 'cat-food';
  const transport = 'cat-transport';
  const salary = 'cat-salary';

  Future<void> insertTx(
    String id,
    String categoryId,
    double amount, {
    String type = 'expense',
    required String date,
    bool isTransfer = false,
    String createdAt = '2026-03-25T09:00:00.000',
  }) {
    return db.insert('transactions', {
      'id': id,
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': 'acc-1',
      'isTransfer': isTransfer ? 1 : 0,
      'date': date,
      'createdAt': createdAt,
    });
  }

  setUp(() async {
    db = await _openTestDb();

    // Inside the period, in the budget's categories.
    await insertTx('in-1', food, 120000, date: '2026-03-25'); // first day
    await insertTx('in-2', food, 45000, date: '2026-04-10');
    await insertTx('in-3', transport, 30000, date: '2026-04-24'); // last day

    // Excluded for one reason each.
    await insertTx('out-category', salary, 5000000, type: 'income', date: '2026-04-01');
    await insertTx('out-before', food, 999, date: '2026-03-24');
    await insertTx('out-after', food, 888, date: '2026-04-25');
    await insertTx('out-transfer', food, 777, date: '2026-04-05', isTransfer: true);
  });

  tearDown(() async => db.close());

  group('getCategoriesByDateRange', () {
    test('returns only the listed categories, within the period', () async {
      final rows = await categoriesByDateRange(db, [food, transport], start, end);

      expect(
        rows.map((r) => r['id']).toSet(),
        {'in-1', 'in-2', 'in-3'},
      );
    });

    test('excludes transfer legs, which were never spending', () async {
      final rows = await categoriesByDateRange(db, [food], start, end);

      expect(rows.map((r) => r['id']), isNot(contains('out-transfer')));
    });

    test('includes both period boundary days', () async {
      final rows = await categoriesByDateRange(db, [food, transport], start, end);
      final dates = rows.map((r) => r['date']).toSet();

      expect(dates, containsAll(<String>['2026-03-25', '2026-04-24']));
    });

    test('returns nothing for a budget with no categories', () async {
      // The 'overall' scope passes an empty list; without this guard the
      // `IN ()` clause is a syntax error.
      expect(await categoriesByDateRange(db, [], start, end), isEmpty);
    });

    test('orders newest first, then by insertion time', () async {
      await insertTx('same-day-later', food, 10,
          date: '2026-04-10', createdAt: '2026-04-10T18:00:00.000');
      await insertTx('same-day-earlier', food, 10,
          date: '2026-04-10', createdAt: '2026-04-10T07:00:00.000');

      final rows = await categoriesByDateRange(db, [food, transport], start, end);
      final ids = rows.map((r) => r['id']).toList();

      expect(ids.first, 'in-3'); // 2026-04-24, the latest date
      expect(
        ids.indexOf('same-day-later'),
        lessThan(ids.indexOf('same-day-earlier')),
      );
    });
  });

  group('getByTypeAndDateRange', () {
    test('an overall budget sees every expense but no income', () async {
      final rows = await byTypeAndDateRange(db, 'expense', start, end);

      expect(rows.map((r) => r['id']).toSet(), {'in-1', 'in-2', 'in-3'});
      expect(rows.map((r) => r['id']), isNot(contains('out-category')));
    });

    test('excludes transfer legs', () async {
      final rows = await byTypeAndDateRange(db, 'expense', start, end);

      expect(rows.map((r) => r['id']), isNot(contains('out-transfer')));
    });
  });

  group('list and sum agree', () {
    test('the listed rows add up to the spent figure', () async {
      final rows = await categoriesByDateRange(db, [food, transport], start, end);
      final listed = rows.fold<double>(0, (sum, r) => sum + (r['amount'] as num).toDouble());

      expect(listed, await categoriesSumByDateRange(db, [food, transport], start, end));
      expect(listed, 195000);
    });

    test('still agree when nothing was spent', () async {
      final emptyStart = DateTime(2026, 1, 1);
      final emptyEnd = DateTime(2026, 1, 31);

      expect(await categoriesByDateRange(db, [food], emptyStart, emptyEnd), isEmpty);
      expect(await categoriesSumByDateRange(db, [food], emptyStart, emptyEnd), 0);
    });
  });
}
