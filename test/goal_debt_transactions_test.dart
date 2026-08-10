import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The queries behind a goal's and a debt's detail screen.
///
/// `DatabaseHelper` is a real singleton bound to the on-disk database path,
/// so `TransactionRepository` isn't test-injectable — as in
/// budget_transactions_test.dart, these tests pin the exact `WHERE` clauses
/// the repository uses against an in-memory database.
///
/// The invariant that matters most is that each list reproduces the aggregate
/// its screen prints in the header: `getByGoalId` against
/// `GoalRepository.getAllProgress`, `getByDebtId` against
/// `DebtRepository.getAllRepaid`. Progress and repaid totals are derived, not
/// stored, so any drift between the row clause and the sum clause reads to
/// the user as a lost contribution.
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
      goalId TEXT,
      debtId TEXT,
      date TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');
  return db;
}

// --- The repository's clauses, verbatim. ---

Future<List<Map<String, Object?>>> byGoalId(Database db, String goalId) {
  return db.query(
    'transactions',
    where: 'goalId = ?',
    whereArgs: [goalId],
    orderBy: 'date DESC, createdAt DESC',
  );
}

Future<List<Map<String, Object?>>> byDebtId(Database db, String debtId) {
  return db.query(
    'transactions',
    where: 'debtId = ?',
    whereArgs: [debtId],
    orderBy: 'date DESC, createdAt DESC',
  );
}

/// `GoalRepository.getAllProgress` — an expense is a contribution, an income
/// is a withdrawal back out of the goal.
Future<Map<String, double>> allGoalProgress(Database db) async {
  final rows = await db.rawQuery(
    "SELECT goalId, SUM(CASE WHEN type = 'expense' THEN amount ELSE -amount END) as total "
    'FROM transactions WHERE goalId IS NOT NULL GROUP BY goalId',
  );
  return {
    for (final r in rows) r['goalId'] as String: (r['total'] as num).toDouble(),
  };
}

/// `DebtRepository.getAllRepaid` — deliberately type-agnostic: a borrowed
/// debt is repaid with expenses, a lent one with income, and both count.
Future<Map<String, double>> allDebtRepaid(Database db) async {
  final rows = await db.rawQuery(
    'SELECT debtId, SUM(amount) as total FROM transactions '
    'WHERE debtId IS NOT NULL GROUP BY debtId',
  );
  return {
    for (final r in rows) r['debtId'] as String: (r['total'] as num).toDouble(),
  };
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  const laptop = 'goal-laptop';
  const house = 'goal-house';
  const cardDebt = 'debt-card';
  const friendDebt = 'debt-friend';

  Future<void> insertTx(
    String id, {
    required double amount,
    String type = 'expense',
    String? goalId,
    String? debtId,
    required String date,
    String createdAt = '2026-03-01T09:00:00.000',
  }) {
    return db.insert('transactions', {
      'id': id,
      'type': type,
      'amount': amount,
      'categoryId': 'cat-savings',
      'accountId': 'acc-1',
      'isTransfer': 0,
      'goalId': goalId,
      'debtId': debtId,
      'date': date,
      'createdAt': createdAt,
    });
  }

  setUp(() async {
    db = await _openTestDb();

    // Laptop goal: two contributions and one withdrawal back out.
    await insertTx('g1', amount: 1500000, goalId: laptop, date: '2026-03-02');
    await insertTx('g2', amount: 2000000, goalId: laptop, date: '2026-04-10');
    await insertTx('g3', amount: 500000, type: 'income', goalId: laptop, date: '2026-04-15');

    // A different goal, and an untagged expense — neither may leak in.
    await insertTx('g4', amount: 900000, goalId: house, date: '2026-04-11');
    await insertTx('g5', amount: 75000, date: '2026-04-12');

    // Borrowed debt repaid with expenses; lent debt repaid with income.
    await insertTx('d1', amount: 300000, debtId: cardDebt, date: '2026-03-20');
    await insertTx('d2', amount: 450000, debtId: cardDebt, date: '2026-04-05');
    await insertTx('d3', amount: 250000, type: 'income', debtId: friendDebt, date: '2026-04-06');
  });

  tearDown(() async => db.close());

  group('getByGoalId', () {
    test('returns only the rows tagged with that goal', () async {
      final rows = await byGoalId(db, laptop);

      expect(rows.map((r) => r['id']), containsAll(['g1', 'g2', 'g3']));
      expect(rows, hasLength(3));
      expect(rows.map((r) => r['id']), isNot(contains('g4')));
      expect(rows.map((r) => r['id']), isNot(contains('g5')));
    });

    test('orders newest first', () async {
      final rows = await byGoalId(db, laptop);

      expect(rows.map((r) => r['id']).toList(), ['g3', 'g2', 'g1']);
    });

    test('includes withdrawals, not just contributions', () async {
      final rows = await byGoalId(db, laptop);
      final withdrawal = rows.firstWhere((r) => r['id'] == 'g3');

      expect(withdrawal['type'], 'income');
    });

    test('the listed rows sum to the derived progress', () async {
      final rows = await byGoalId(db, laptop);
      final listed = rows.fold<double>(
        0,
        (sum, r) => sum + (r['type'] == 'expense' ? 1 : -1) * (r['amount'] as num).toDouble(),
      );

      final progress = await allGoalProgress(db);
      expect(listed, progress[laptop]);
      // 1,500,000 + 2,000,000 − 500,000
      expect(listed, 3000000);
    });

    test('an unknown goal lists nothing and scores zero', () async {
      expect(await byGoalId(db, 'goal-missing'), isEmpty);

      final progress = await allGoalProgress(db);
      expect(progress['goal-missing'], isNull);
    });
  });

  group('getByDebtId', () {
    test('returns only the rows tagged with that debt, newest first', () async {
      final rows = await byDebtId(db, cardDebt);

      expect(rows.map((r) => r['id']).toList(), ['d2', 'd1']);
    });

    test('the listed rows sum to the derived repaid total', () async {
      final rows = await byDebtId(db, cardDebt);
      final listed = rows.fold<double>(0, (sum, r) => sum + (r['amount'] as num).toDouble());

      final repaid = await allDebtRepaid(db);
      expect(listed, repaid[cardDebt]);
      expect(listed, 750000);
    });

    test('counts income repayments on a lent debt', () async {
      final rows = await byDebtId(db, friendDebt);
      expect(rows.map((r) => r['id']).toList(), ['d3']);
      expect(rows.single['type'], 'income');

      final repaid = await allDebtRepaid(db);
      expect(repaid[friendDebt], 250000);
    });

    test('a goal contribution never counts as a debt repayment', () async {
      final repaid = await allDebtRepaid(db);

      expect(repaid.keys, unorderedEquals([cardDebt, friendDebt]));
    });

    test('an unknown debt lists nothing and scores zero', () async {
      expect(await byDebtId(db, 'debt-missing'), isEmpty);

      final repaid = await allDebtRepaid(db);
      expect(repaid['debt-missing'], isNull);
    });
  });
}
