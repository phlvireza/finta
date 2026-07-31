import 'package:sqflite/sqflite.dart';
import '../database/seed_data.dart';

/// Incremental schema migrations, one static method per version bump.
/// Each must be safe to run against a populated production database —
/// use ALTER TABLE / CREATE INDEX, never DROP TABLE.
class Migrations {
  Migrations._();

  /// v1 → v2: adds category archiving (see `CategoryRepository.archive`)
  /// and a partial unique index that makes recurring-transaction
  /// generation idempotent (see `RecurringService`).
  static Future<void> v2(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        'ALTER TABLE categories ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0',
      );
      await createRecurringOccurrenceIndex(txn);
    });
  }

  /// v2 → v3: adds accounts + transfers, merchant, and (2-level)
  /// sub-categories. Every pre-existing transaction is backfilled onto a
  /// generated "My Wallet" account via the ALTER TABLE ... DEFAULT below —
  /// nothing is left orphaned and no separate UPDATE pass is needed.
  static Future<void> v3(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        'ALTER TABLE categories ADD COLUMN parentId TEXT',
      );
      await txn.execute(
        'ALTER TABLE categories ADD COLUMN isSystem INTEGER NOT NULL DEFAULT 0',
      );

      await txn.execute(createAccountsTable);
      await SeedData.seedDefaultAccount(txn);
      await SeedData.seedSystemCategory(txn);

      // DEFAULT '${SeedData.defaultAccountId}' backfills every existing
      // row in the same statement — no separate UPDATE pass needed.
      await txn.execute(
        "ALTER TABLE transactions ADD COLUMN accountId TEXT NOT NULL "
        "DEFAULT '${SeedData.defaultAccountId}'",
      );
      await txn.execute('ALTER TABLE transactions ADD COLUMN transferId TEXT');
      await txn.execute(
        'ALTER TABLE transactions ADD COLUMN isTransfer INTEGER NOT NULL DEFAULT 0',
      );
      await txn.execute('ALTER TABLE transactions ADD COLUMN merchant TEXT');
      await txn.execute(
        'CREATE INDEX idx_transactions_accountId ON transactions(accountId)',
      );

      await txn.execute(
        'ALTER TABLE recurring_transactions ADD COLUMN accountId TEXT',
      );
    });
  }

  /// v3 → v4: budget system upgrade — period length, rollover, and
  /// group/overall scope. `budgets.categoryId UNIQUE` can't be relaxed
  /// with ALTER TABLE, so this is the one legitimate 12-step table
  /// rebuild in the codebase: every existing row is copied into the new
  /// shape (as a 'category'-scoped, 'monthly', no-rollover budget — i.e.
  /// unchanged behavior) before the old table is dropped, so nothing is
  /// lost and no existing budget's numbers move.
  static Future<void> v4(Database db) async {
    await db.transaction((txn) async {
      final existing = await txn.query('budgets');

      await txn.execute(createBudgetsTableTemp);
      await txn.execute(createBudgetCategoriesTable);

      final batch = txn.batch();
      for (final row in existing) {
        batch.insert('budgets_new', {
          'id': row['id'],
          'name': null,
          'amount': row['amount'],
          'period': 'monthly',
          'rolloverMode': 'none',
          'scope': 'category',
          'isActive': row['isActive'],
          'createdAt': row['createdAt'],
          'updatedAt': row['updatedAt'],
        });
        batch.insert('budget_categories', {
          'budgetId': row['id'],
          'categoryId': row['categoryId'],
        });
      }
      await batch.commit(noResult: true);

      await txn.execute('DROP TABLE budgets');
      await txn.execute('ALTER TABLE budgets_new RENAME TO budgets');
    });
  }

  /// v4 → v5: goals and debts. Both are tracked as their own small tables
  /// (principal/target live there) while actual money movement — a
  /// contribution or a repayment — is just an ordinary transaction tagged
  /// with `goalId`/`debtId`. That keeps goal/debt progress fully derived
  /// (SUM over tagged transactions, same "compute on the fly" choice as
  /// budget rollover) instead of a second number that can drift out of
  /// sync with the transaction history, and it means every existing
  /// transaction feature (edit, delete, search, CSV export) works on
  /// contributions/repayments for free.
  static Future<void> v5(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(createGoalsTable);
      await txn.execute(createDebtsTable);
      await txn.execute('ALTER TABLE transactions ADD COLUMN goalId TEXT');
      await txn.execute('ALTER TABLE transactions ADD COLUMN debtId TEXT');
      await txn.execute('CREATE INDEX idx_transactions_goalId ON transactions(goalId)');
      await txn.execute('CREATE INDEX idx_transactions_debtId ON transactions(debtId)');
      await SeedData.seedGoalDebtCategories(txn);
    });
  }

  /// v5 → v6: subscriptions are just recurring templates with a couple of
  /// extra flags rather than a separate table — `isSubscription` marks one
  /// for the Subscriptions screen, `isPaused` stops it from generating
  /// charges without deactivating (and losing) the template the way
  /// deleting would, and `reminderDaysBefore` (nullable — null means no
  /// reminder) drives the local-notification schedule. `merchant` lets a
  /// subscription show a real name ("Netflix") instead of just its
  /// category.
  static Future<void> v6(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE recurring_transactions ADD COLUMN merchant TEXT');
      await txn.execute(
        'ALTER TABLE recurring_transactions ADD COLUMN isSubscription INTEGER NOT NULL DEFAULT 0',
      );
      await txn.execute(
        'ALTER TABLE recurring_transactions ADD COLUMN isPaused INTEGER NOT NULL DEFAULT 0',
      );
      await txn.execute(
        'ALTER TABLE recurring_transactions ADD COLUMN reminderDaysBefore INTEGER',
      );
    });
  }

  static const String createGoalsTable = '''
    CREATE TABLE goals (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      targetAmount REAL NOT NULL,
      targetDate TEXT,
      icon TEXT NOT NULL DEFAULT 'savings',
      color TEXT NOT NULL,
      isArchived INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL
    )
  ''';

  static const String createDebtsTable = '''
    CREATE TABLE debts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      principal REAL NOT NULL,
      dueDate TEXT,
      interestRate REAL,
      note TEXT,
      isArchived INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL
    )
  ''';

  /// Used by [v4]: the new budgets table is built under a temporary name
  /// during the rebuild (the live `budgets` table can't be replaced until
  /// its data is copied out), then renamed. [createBudgetsTable] below is
  /// the same shape under the real name, for fresh installs.
  static const String createBudgetsTableTemp = '''
    CREATE TABLE budgets_new (
      id TEXT PRIMARY KEY,
      name TEXT,
      amount REAL NOT NULL,
      period TEXT NOT NULL DEFAULT 'monthly',
      rolloverMode TEXT NOT NULL DEFAULT 'none',
      scope TEXT NOT NULL DEFAULT 'category',
      isActive INTEGER NOT NULL DEFAULT 1,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''';

  /// Shared by `DatabaseHelper._onCreate` (fresh installs) — same shape as
  /// [createBudgetsTableTemp], under the real table name.
  static const String createBudgetsTable = '''
    CREATE TABLE budgets (
      id TEXT PRIMARY KEY,
      name TEXT,
      amount REAL NOT NULL,
      period TEXT NOT NULL DEFAULT 'monthly',
      rolloverMode TEXT NOT NULL DEFAULT 'none',
      scope TEXT NOT NULL DEFAULT 'category',
      isActive INTEGER NOT NULL DEFAULT 1,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''';

  static const String createBudgetCategoriesTable = '''
    CREATE TABLE budget_categories (
      budgetId TEXT NOT NULL,
      categoryId TEXT NOT NULL,
      PRIMARY KEY (budgetId, categoryId),
      FOREIGN KEY (budgetId) REFERENCES budgets(id) ON DELETE CASCADE,
      FOREIGN KEY (categoryId) REFERENCES categories(id)
    )
  ''';

  /// Shared by `DatabaseHelper._onCreate` (fresh installs) and [v3]
  /// (upgrades) so both paths converge on an identical `accounts` schema.
  static const String createAccountsTable = '''
    CREATE TABLE accounts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      openingBalance REAL NOT NULL DEFAULT 0,
      color TEXT NOT NULL,
      creditLimit REAL,
      isArchived INTEGER NOT NULL DEFAULT 0,
      includeInTotal INTEGER NOT NULL DEFAULT 1,
      sortOrder INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL
    )
  ''';

  /// Shared by `DatabaseHelper._onCreate` (fresh installs) and [v2]
  /// (upgrades) so both paths converge on an identical index.
  static Future<void> createRecurringOccurrenceIndex(
    DatabaseExecutor db,
  ) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_recurring_occurrence '
      'ON transactions(recurringId, date) WHERE recurringId IS NOT NULL',
    );
  }
}
