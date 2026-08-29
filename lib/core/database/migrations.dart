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

      final budgetsBatch = txn.batch();
      for (final row in existing) {
        budgetsBatch.insert('budgets_new', {
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
      }
      await budgetsBatch.commit(noResult: true);

      await txn.execute('DROP TABLE budgets');
      await txn.execute('ALTER TABLE budgets_new RENAME TO budgets');

      // budget_categories (FK budgetId -> budgets(id) ON DELETE CASCADE) is
      // created only now, after the rename. Creating it earlier and
      // inserting into it before `DROP TABLE budgets` above would make
      // SQLite's implicit FK cleanup on that drop cascade into it and
      // silently wipe every link we'd just inserted.
      await txn.execute(createBudgetCategoriesTable);

      final linksBatch = txn.batch();
      for (final row in existing) {
        linksBatch.insert('budget_categories', {
          'budgetId': row['id'],
          'categoryId': row['categoryId'],
        });
      }
      await linksBatch.commit(noResult: true);
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

  /// v6 → v7: transaction templates ("favorites") for one-tap quick add —
  /// a saved bundle of type/amount/category/account/merchant/note that
  /// materializes into a normal transaction the moment it's tapped, dated
  /// whenever it's used rather than when it was saved.
  static Future<void> v7(Database db) async {
    await db.execute(createTemplatesTable);
  }

  /// v7 → v8: adds the "Donation" default expense category. Data-only —
  /// no schema change — so a fresh install (which seeds the same row from
  /// `_onCreate`) and an upgraded one still converge exactly.
  ///
  /// Safe to replay: the row carries a fixed id and is inserted with
  /// `ConflictAlgorithm.ignore`, and a user who has since archived or
  /// renamed it keeps their version rather than having it reset.
  static Future<void> v8(Database db) async {
    await SeedData.seedDonationCategory(db);
  }

  /// v8 → v9: `isRecurring` on budgets.
  ///
  /// Budgets have never had a period anchor — the date range is derived at
  /// read time from the *current* period, so every budget re-applied
  /// forever with no way to opt out. This column makes that intent
  /// explicit and lets a budget cover only the period it was created in.
  ///
  /// `DEFAULT 1` is load-bearing: it backfills every already-shipped
  /// budget as recurring, preserving exactly the behaviour those budgets
  /// have today. Without it, an upgrading install would see all of its
  /// budgets expire at the next payday. New budgets default to *off* —
  /// that choice lives in the form, not in the schema.
  static Future<void> v9(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        'ALTER TABLE budgets ADD COLUMN isRecurring INTEGER NOT NULL DEFAULT 1',
      );
    });
  }

  /// v9 → v10: two data repairs. No DDL at all, so a fresh `_onCreate`
  /// install and a fully-upgraded one still produce an identical schema.
  ///
  /// **1. Merchant backfill.** `RecurringService._materialize` never copied
  /// `merchant` off the template, so only the first occurrence (the one the
  /// entry form posts inline) ever carried one. Every generated occurrence
  /// after it landed with `merchant` NULL and was then invisible to Top
  /// Merchants, the merchant autocomplete, `getMerchantDefaults` and
  /// subscription detection — all four filter on `merchant IS NOT NULL`.
  /// The service is fixed going forward; this repairs what already posted.
  /// The `IS NULL OR TRIM(...) = ''` guard means a merchant the user typed
  /// onto one of those rows by hand is never overwritten.
  ///
  /// **2. Default category colours.** Two seeded categories shipped with
  /// `#D4A05A`, which is `AppColors.warning` exactly — so their budget bars
  /// wore the "over budget" amber as an identity colour. The seed list now
  /// draws from the chart ramp instead. Matching on `color = <old hex>` is
  /// the whole point: a category the user re-coloured keeps their choice,
  /// and re-running the migration can't undo a later edit.
  ///
  /// Rows are matched by name + type because seeded category ids are fresh
  /// uuids rather than fixed constants.
  ///
  /// Do not copy that pattern into a new migration. Default category names are
  /// now rewritten into the user's language after startup (see
  /// `core/utils/default_category_names.dart`), so a `WHERE name = '<English>'`
  /// matches nothing on a device running in another language — silently, since
  /// an UPDATE that hits zero rows is not an error. Key on the id, or on a
  /// column the app never rewrites such as colour. This migration is safe only
  /// because it has already run everywhere the rename could apply.
  static Future<void> v10(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('''
        UPDATE transactions
        SET merchant = (
          SELECT r.merchant FROM recurring_transactions r
          WHERE r.id = transactions.recurringId
        )
        WHERE recurringId IS NOT NULL
          AND (merchant IS NULL OR TRIM(merchant) = '')
          AND EXISTS (
            SELECT 1 FROM recurring_transactions r
            WHERE r.id = transactions.recurringId
              AND r.merchant IS NOT NULL
              AND TRIM(r.merchant) != ''
          )
      ''');

      for (final entry in seedCategoryRecolours) {
        await txn.update(
          'categories',
          {'color': entry.newColor},
          where: 'isDefault = 1 AND type = ? AND name = ? AND color = ?',
          whereArgs: [entry.type, entry.name, entry.oldColor],
        );
      }
    });
  }

  /// v10 → v11: records that the user has dealt with a one-off budget's
  /// unspent money, so the prompt offering to roll it forward can be
  /// answered once and stay answered.
  ///
  /// Nullable rather than a flag with a default: NULL means "still needs an
  /// answer", and the timestamp of the answer is the only other state worth
  /// keeping. Nothing derived is stored — the leftover itself is recomputed
  /// from transactions on every load, like every other budget figure.
  ///
  /// The backfill is the load-bearing half. Budgets that had already ended
  /// before this shipped never got the chance to be answered, and without it
  /// an upgrading install would open to a card listing every one-off budget
  /// it has ever retired. Stamping them with `updatedAt` — the moment
  /// `BudgetExpiryService` retired them — reads as "answered when it ended"
  /// and leaves only budgets that expire from here on to prompt.
  static Future<void> v11(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE budgets ADD COLUMN leftoverResolvedAt TEXT');
      await txn.execute(
        'UPDATE budgets SET leftoverResolvedAt = updatedAt WHERE isActive = 0',
      );
    });
  }

  /// v11 → v12: cuts `transactions.recurringId` loose from templates that are
  /// no longer live. Data only, no DDL, so a fresh `_onCreate` install and a
  /// fully-upgraded one still produce an identical schema.
  ///
  /// Stopping a recurring template used to deactivate the template and stop
  /// there. `TransactionModel.isRecurring` is just `recurringId != null`, so
  /// every occurrence it had already posted kept drawing the repeat badge —
  /// pointing at a schedule that every screen filters out on `isActive`, and
  /// that the user could therefore never see, pause or resume again. The badge
  /// outlived the thing it described. `RecurringRepository.delete` now unlinks
  /// as it deactivates; this repairs the rows stopped before that existed.
  ///
  /// The second statement covers ids that resolve to no row at all — a
  /// `hardDelete`, or a backup restored without its templates. Those are the
  /// same stale badge with no row left to explain it.
  ///
  /// Transactions are only unlinked, never deleted: the money was really
  /// spent, and unlike a goal or a debt there is nothing to give back.
  /// Occurrences of *active* templates are untouched — their badge is honest.
  static Future<void> v12(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('''
        UPDATE transactions SET recurringId = NULL
        WHERE recurringId IS NOT NULL
          AND recurringId IN (
            SELECT id FROM recurring_transactions WHERE isActive = 0
          )
      ''');

      await txn.execute('''
        UPDATE transactions SET recurringId = NULL
        WHERE recurringId IS NOT NULL
          AND recurringId NOT IN (SELECT id FROM recurring_transactions)
      ''');
    });
  }

  /// The v10 colour moves, kept beside the migration that applies them so
  /// the "before" hex stays readable — [SeedData] only records the "after".
  static const List<({String type, String name, String oldColor, String newColor})>
      seedCategoryRecolours = [
    (type: 'expense', name: 'Food & Drinks', oldColor: '#C87941', newColor: '#3F8B4C'),
    (type: 'expense', name: 'Transport', oldColor: '#6F8B8A', newColor: '#2E5FA8'),
    (type: 'expense', name: 'Shopping', oldColor: '#C2665A', newColor: '#C13F55'),
    (type: 'expense', name: 'Bills & Utilities', oldColor: '#D4A05A', newColor: '#C1661E'),
    (type: 'expense', name: 'Entertainment', oldColor: '#8B6F7A', newColor: '#7B5B9E'),
    (type: 'expense', name: 'Health', oldColor: '#5B8C5A', newColor: '#12928C'),
    (type: 'expense', name: 'Education', oldColor: '#7A8B6F', newColor: '#A0522D'),
    (type: 'expense', name: 'Groceries', oldColor: '#B07A5B', newColor: '#C87941'),
    (type: 'income', name: 'Salary', oldColor: '#5B8C5A', newColor: '#3F8B4C'),
    (type: 'income', name: 'Freelance', oldColor: '#C87941', newColor: '#2E5FA8'),
    (type: 'income', name: 'Gift', oldColor: '#D4A05A', newColor: '#7B5B9E'),
    (type: 'income', name: 'Investment', oldColor: '#7A8B6F', newColor: '#12928C'),
  ];

  static const String createTemplatesTable = '''
    CREATE TABLE templates (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      categoryId TEXT NOT NULL,
      accountId TEXT NOT NULL,
      merchant TEXT,
      note TEXT,
      sortOrder INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (categoryId) REFERENCES categories(id),
      FOREIGN KEY (accountId) REFERENCES accounts(id)
    )
  ''';

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

  /// Shared by `DatabaseHelper._onCreate` (fresh installs) — the v4 shape
  /// from [createBudgetsTableTemp] plus every column added by a later
  /// migration.
  ///
  /// `isRecurring` sits last, after `updatedAt`, because [v9] adds it with
  /// `ALTER TABLE … ADD COLUMN`, which always appends. Moving it up beside
  /// the other flags would make a fresh install's column order diverge
  /// from an upgraded one. `leftoverResolvedAt` follows it for the same
  /// reason — [v11] appends it.
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
      updatedAt TEXT NOT NULL,
      isRecurring INTEGER NOT NULL DEFAULT 1,
      leftoverResolvedAt TEXT
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
