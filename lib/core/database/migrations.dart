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
