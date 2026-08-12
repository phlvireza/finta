import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:finta/core/utils/merchant_utils.dart';

/// `TransactionRepository.getMerchantTotals` and the fold that consumes it.
///
/// `DatabaseHelper` is a singleton bound to the on-disk path, so the query is
/// pinned here verbatim rather than driven through the repository — the same
/// arrangement goal_debt_transactions_test.dart uses.
///
/// The contract split between the two halves is the point of these tests: the
/// query must return *every* spelling with no ranking and no limit, and
/// [foldMerchantTotals] must be what merges and cuts them. A `LIMIT` pushed
/// into SQL would silently drop a merchant that only ranks once its variants
/// are added up.
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
      accountId TEXT NOT NULL,
      isTransfer INTEGER NOT NULL DEFAULT 0,
      merchant TEXT,
      date TEXT NOT NULL
    )
  ''');
  return db;
}

/// The repository's clause, verbatim.
Future<List<Map<String, Object?>>> merchantTotals(
  Database db,
  String type,
  String start,
  String end,
) {
  return db.rawQuery(
    'SELECT merchant, SUM(amount) as total, COUNT(*) as cnt FROM transactions '
    "WHERE type = ? AND isTransfer = 0 AND merchant IS NOT NULL AND TRIM(merchant) != '' "
    'AND date >= ? AND date <= ? '
    'GROUP BY merchant',
    [type, start, end],
  );
}

List<MerchantAnalytics> fold(List<Map<String, Object?>> rows, {int limit = 10}) {
  return foldMerchantTotals(
    rows.map((row) => (
          merchant: row['merchant'] as String,
          total: (row['total'] as num).toDouble(),
          count: row['cnt'] as int,
        )),
    limit: limit,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  var nextId = 0;

  Future<void> insertTx({
    String? merchant,
    required double amount,
    required String date,
    String type = 'expense',
    bool isTransfer = false,
  }) {
    return db.insert('transactions', {
      'id': 'tx-${nextId++}',
      'type': type,
      'amount': amount,
      'accountId': 'acc-1',
      'isTransfer': isTransfer ? 1 : 0,
      'merchant': merchant,
      'date': date,
    });
  }

  setUp(() async {
    db = await _openTestDb();
    nextId = 0;
  });

  tearDown(() async => db.close());

  test('returns one row per raw spelling, unranked and uncut', () async {
    await insertTx(merchant: 'Netflix', amount: 54000, date: '2026-04-15');
    await insertTx(merchant: 'netflix', amount: 54000, date: '2026-04-20');
    await insertTx(merchant: 'Alfamart', amount: 90000, date: '2026-04-18');

    final rows = await merchantTotals(db, 'expense', '2026-04-01', '2026-04-30');

    expect(rows, hasLength(3), reason: 'the query must not fold or limit');
  });

  test('the fold merges the spellings the query kept apart', () async {
    await insertTx(merchant: 'Netflix', amount: 54000, date: '2026-04-15');
    await insertTx(merchant: 'netflix ', amount: 54000, date: '2026-04-20');

    final result = fold(await merchantTotals(db, 'expense', '2026-04-01', '2026-04-30'));

    expect(result, hasLength(1));
    expect(result.single.total, 108000);
    expect(result.single.count, 2);
  });

  test('folding before the cut keeps a merchant a SQL LIMIT would have lost', () async {
    // Netflix outspends both others but only once its three spellings are
    // added together. Cut at 2 on the raw rows it would place 3rd, 4th and 5th.
    await insertTx(merchant: 'Netflix', amount: 40000, date: '2026-04-01');
    await insertTx(merchant: 'netflix', amount: 40000, date: '2026-04-02');
    await insertTx(merchant: 'NETFLIX', amount: 40000, date: '2026-04-03');
    await insertTx(merchant: 'Alfamart', amount: 90000, date: '2026-04-04');
    await insertTx(merchant: 'Indomaret', amount: 80000, date: '2026-04-05');

    final result = fold(
      await merchantTotals(db, 'expense', '2026-04-01', '2026-04-30'),
      limit: 2,
    );

    expect(result.map((m) => m.merchant).toList(), ['Netflix', 'Alfamart']);
    expect(result.first.total, 120000);
  });

  test('excludes transfers, the other type, and rows outside the range', () async {
    await insertTx(merchant: 'Alfamart', amount: 10000, date: '2026-04-10');
    await insertTx(merchant: 'Alfamart', amount: 99999, date: '2026-04-10', isTransfer: true);
    await insertTx(merchant: 'Employer', amount: 99999, date: '2026-04-10', type: 'income');
    await insertTx(merchant: 'Alfamart', amount: 99999, date: '2026-03-31');
    await insertTx(merchant: 'Alfamart', amount: 99999, date: '2026-05-01');

    final result = fold(await merchantTotals(db, 'expense', '2026-04-01', '2026-04-30'));

    expect(result, hasLength(1));
    expect(result.single.merchant, 'Alfamart');
    expect(result.single.total, 10000);
  });

  test('skips null and whitespace-only merchants rather than bucketing them', () async {
    await insertTx(merchant: null, amount: 50000, date: '2026-04-10');
    await insertTx(merchant: '   ', amount: 50000, date: '2026-04-11');
    await insertTx(merchant: 'Alfamart', amount: 10000, date: '2026-04-12');

    final rows = await merchantTotals(db, 'expense', '2026-04-01', '2026-04-30');
    final result = fold(rows);

    expect(rows, hasLength(1), reason: 'TRIM guards the whitespace-only row');
    expect(result.map((m) => m.merchant).toList(), ['Alfamart']);
  });

  test('an empty period yields an empty list, not an error', () async {
    final result = fold(await merchantTotals(db, 'expense', '2026-04-01', '2026-04-30'));

    expect(result, isEmpty);
  });
}
