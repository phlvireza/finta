import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The three outcomes of deleting a goal or debt.
///
/// `DatabaseHelper` is a real singleton bound to the on-disk database path, so
/// `GoalRepository` isn't test-injectable — as in goal_debt_transactions_test
/// .dart, these tests pin the exact statements the repository issues against
/// an in-memory database.
///
/// What matters here is that the two destructive paths stay distinguishable.
/// Archiving must leave every transaction untouched, because a contribution is
/// real spending that already moved an account balance. Deleting with
/// contributions must take both the row *and* its transactions, because a goal
/// created by mistake never spent anything and leaving the expenses behind is
/// what made the money look stranded. And because `goalId`/`debtId` carry no
/// foreign key, nothing in the schema would catch either going half-done.
Future<Database> _openTestDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    ':memory:',
    options: OpenDatabaseOptions(
      version: 1,
      // The real app turns FKs on in DatabaseHelper.onConfigure, and SQLite
      // defaults them off per connection. Without this a test could pass while
      // production cascaded rows away.
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    ),
  );
  await db.execute('''
    CREATE TABLE goals (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      targetAmount REAL NOT NULL,
      isArchived INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE debts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      principal REAL NOT NULL,
      isArchived INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      accountId TEXT NOT NULL,
      goalId TEXT,
      debtId TEXT,
      date TEXT NOT NULL
    )
  ''');
  return db;
}

// --- The repository's statements, verbatim. ---

Future<void> archiveGoal(Database db, String id) =>
    db.update('goals', {'isArchived': 1}, where: 'id = ?', whereArgs: [id]);

Future<void> unarchiveGoal(Database db, String id) =>
    db.update('goals', {'isArchived': 0}, where: 'id = ?', whereArgs: [id]);

Future<void> deleteUnusedGoal(Database db, String id) =>
    db.delete('goals', where: 'id = ?', whereArgs: [id]);

Future<void> deleteGoalWithTransactions(Database db, String id) {
  return db.transaction((txn) async {
    await txn.delete('transactions', where: 'goalId = ?', whereArgs: [id]);
    await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
  });
}

Future<void> deleteDebtWithTransactions(Database db, String id) {
  return db.transaction((txn) async {
    await txn.delete('transactions', where: 'debtId = ?', whereArgs: [id]);
    await txn.delete('debts', where: 'id = ?', whereArgs: [id]);
  });
}

Future<int> countGoalUsage(Database db, String id) async {
  final result = await db.rawQuery(
    'SELECT COUNT(*) as c FROM transactions WHERE goalId = ?',
    [id],
  );
  return result.first['c'] as int;
}

/// The account balance the app derives: opening balance plus the signed sum of
/// its transactions. Recomputed here so a delete can be checked by its effect
/// on the number the user actually sees, not just by row counts.
Future<double> balanceOf(Database db, String accountId, {double opening = 0}) async {
  final rows = await db.rawQuery(
    "SELECT SUM(CASE WHEN type = 'expense' THEN -amount ELSE amount END) as total "
    'FROM transactions WHERE accountId = ?',
    [accountId],
  );
  final total = rows.first['total'];
  return opening + (total == null ? 0 : (total as num).toDouble());
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

  setUp(() async {
    db = await _openTestDb();

    await db.insert('goals', {
      'id': laptop,
      'name': 'Laptop',
      'targetAmount': 20000000,
      'isArchived': 0,
    });
    await db.insert('goals', {
      'id': house,
      'name': 'House',
      'targetAmount': 500000000,
      'isArchived': 0,
    });
    await db.insert('debts', {
      'id': cardDebt,
      'name': 'Credit card',
      'principal': 5000000,
      'isArchived': 0,
    });

    // Two contributions to the laptop, one to the house, one repayment, and
    // one ordinary expense that belongs to neither.
    await db.insert('transactions', {
      'id': 'g1',
      'type': 'expense',
      'amount': 1500000,
      'accountId': 'acc-1',
      'goalId': laptop,
      'date': '2026-03-02',
    });
    await db.insert('transactions', {
      'id': 'g2',
      'type': 'expense',
      'amount': 2000000,
      'accountId': 'acc-1',
      'goalId': laptop,
      'date': '2026-04-10',
    });
    await db.insert('transactions', {
      'id': 'g3',
      'type': 'expense',
      'amount': 900000,
      'accountId': 'acc-1',
      'goalId': house,
      'date': '2026-04-11',
    });
    await db.insert('transactions', {
      'id': 'd1',
      'type': 'expense',
      'amount': 300000,
      'accountId': 'acc-1',
      'debtId': cardDebt,
      'date': '2026-04-05',
    });
    await db.insert('transactions', {
      'id': 'x1',
      'type': 'expense',
      'amount': 75000,
      'accountId': 'acc-1',
      'date': '2026-04-12',
    });
  });

  tearDown(() async => db.close());

  group('archive', () {
    test('leaves every contribution in place', () async {
      await archiveGoal(db, laptop);

      expect(await countGoalUsage(db, laptop), 2);
    });

    test('leaves the account balance untouched', () async {
      final before = await balanceOf(db, 'acc-1', opening: 10000000);
      await archiveGoal(db, laptop);

      expect(await balanceOf(db, 'acc-1', opening: 10000000), before);
    });

    test('keeps the goal row so its name still resolves', () async {
      await archiveGoal(db, laptop);
      final rows = await db.query('goals', where: 'id = ?', whereArgs: [laptop]);

      expect(rows.single['name'], 'Laptop');
      expect(rows.single['isArchived'], 1);
    });

    test('unarchive round-trips without touching transactions', () async {
      await archiveGoal(db, laptop);
      await unarchiveGoal(db, laptop);
      final rows = await db.query('goals', where: 'id = ?', whereArgs: [laptop]);

      expect(rows.single['isArchived'], 0);
      expect(await countGoalUsage(db, laptop), 2);
    });
  });

  group('deleteWithTransactions', () {
    test('removes the goal and its contributions', () async {
      await deleteGoalWithTransactions(db, laptop);

      expect(await db.query('goals', where: 'id = ?', whereArgs: [laptop]), isEmpty);
      expect(await countGoalUsage(db, laptop), 0);
    });

    test('gives the money back to the account balance', () async {
      // 10,000,000 opening − 1,500,000 − 2,000,000 − 900,000 − 300,000 − 75,000
      expect(await balanceOf(db, 'acc-1', opening: 10000000), 5225000);

      await deleteGoalWithTransactions(db, laptop);

      // The laptop's 3,500,000 comes back; nothing else moves.
      expect(await balanceOf(db, 'acc-1', opening: 10000000), 8725000);
    });

    test('leaves another goal, a debt and untagged transactions alone', () async {
      await deleteGoalWithTransactions(db, laptop);
      final remaining = await db.query('transactions');

      expect(remaining.map((r) => r['id']), unorderedEquals(['g3', 'd1', 'x1']));
      expect(await db.query('goals', where: 'id = ?', whereArgs: [house]), hasLength(1));
      expect(await db.query('debts'), hasLength(1));
    });

    test('deleting a debt takes its repayments and only those', () async {
      await deleteDebtWithTransactions(db, cardDebt);
      final remaining = await db.query('transactions');

      expect(remaining.map((r) => r['id']), unorderedEquals(['g1', 'g2', 'g3', 'x1']));
      expect(await db.query('debts'), isEmpty);
    });

    test('a goal with no contributions deletes cleanly either way', () async {
      await db.insert('goals', {
        'id': 'goal-empty',
        'name': 'Empty',
        'targetAmount': 100,
        'isArchived': 0,
      });

      expect(await countGoalUsage(db, 'goal-empty'), 0);
      await deleteUnusedGoal(db, 'goal-empty');

      expect(await db.query('goals', where: 'id = ?', whereArgs: ['goal-empty']), isEmpty);
      // No transactions were harmed reaching that outcome.
      expect(await db.query('transactions'), hasLength(5));
    });

    test('deleting an unknown goal is a no-op, not a wipe', () async {
      await deleteGoalWithTransactions(db, 'goal-missing');

      expect(await db.query('transactions'), hasLength(5));
      expect(await db.query('goals'), hasLength(2));
    });
  });
}
