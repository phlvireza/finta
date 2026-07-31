import 'package:sqflite/sqflite.dart';

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
