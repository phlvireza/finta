import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:finta/core/database/migrations.dart';

/// Frozen snapshot of the original v1 `onCreate` — this is what an
/// existing, already-shipped install actually looks like before upgrading.
/// It must NOT be changed to track later schema versions.
Future<void> _createV1Schema(Database db, int version) async {
  await db.execute('''
    CREATE TABLE categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      icon TEXT NOT NULL,
      color TEXT NOT NULL,
      isDefault INTEGER NOT NULL DEFAULT 0,
      sortOrder INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      categoryId TEXT NOT NULL,
      date TEXT NOT NULL,
      note TEXT,
      recurringId TEXT,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      FOREIGN KEY (categoryId) REFERENCES categories(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE recurring_transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      categoryId TEXT NOT NULL,
      note TEXT,
      frequency TEXT NOT NULL,
      startDate TEXT NOT NULL,
      endDate TEXT,
      lastRunDate TEXT,
      isActive INTEGER NOT NULL DEFAULT 1,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (categoryId) REFERENCES categories(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE budgets (
      id TEXT PRIMARY KEY,
      categoryId TEXT NOT NULL UNIQUE,
      amount REAL NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      FOREIGN KEY (categoryId) REFERENCES categories(id)
    )
  ''');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'migrating a populated v1 database to v2 preserves data and adds the new schema',
    () async {
      // Simulate an existing v1 install that already has real user data.
      final v1 = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(version: 1, onCreate: _createV1Schema),
      );

      await v1.insert('categories', {
        'id': 'cat1',
        'name': 'Coffee',
        'type': 'expense',
        'icon': 'local_cafe',
        'color': '#C87941',
        'isDefault': 0,
        'sortOrder': 0,
        'createdAt': '2026-01-01T00:00:00.000',
      });
      await v1.insert('transactions', {
        'id': 'tx1',
        'type': 'expense',
        'amount': 45000,
        'categoryId': 'cat1',
        'date': '2026-07-01',
        'note': null,
        'recurringId': null,
        'createdAt': '2026-07-01T00:00:00.000',
        'updatedAt': '2026-07-01T00:00:00.000',
      });

      // Apply the real migration in place — this is the exact code path a
      // shipped app runs on the next launch after an update.
      await Migrations.v2(v1);

      final categories = await v1.query('categories');
      expect(categories, hasLength(1));
      expect(categories.first['name'], 'Coffee');
      // ALTER TABLE ... DEFAULT 0 backfills every pre-existing row.
      expect(categories.first['isArchived'], 0);

      final transactions = await v1.query('transactions');
      expect(transactions, hasLength(1));
      expect(transactions.first['amount'], 45000);

      await v1.close();
    },
  );

  test(
    'the recurring-occurrence index makes catch-up generation idempotent',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(version: 1, onCreate: _createV1Schema),
      );
      await Migrations.v2(db);

      final row = {
        'id': 'tx1',
        'type': 'expense',
        'amount': 100000,
        'categoryId': 'cat1',
        'date': '2026-07-01',
        'note': null,
        'recurringId': 'rec1',
        'createdAt': '2026-07-01T00:00:00.000',
        'updatedAt': '2026-07-01T00:00:00.000',
      };
      await db.insert(
        'transactions',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      // Same recurringId + date, different primary key — simulates
      // RecurringService re-running after a crash, before lastRunDate
      // was persisted.
      await db.insert(
        'transactions',
        {...row, 'id': 'tx2'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final rows = await db.query(
        'transactions',
        where: "recurringId = 'rec1'",
      );
      expect(
        rows,
        hasLength(1),
        reason: 'the partial unique index should reject the duplicate occurrence',
      );

      await db.close();
    },
  );

  test(
    'migrating a populated v2 database to v3 adds accounts, backfills '
    'accountId on every existing transaction, and seeds the Transfer '
    'system category',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(version: 1, onCreate: _createV1Schema),
      );
      await db.insert('categories', {
        'id': 'cat1',
        'name': 'Coffee',
        'type': 'expense',
        'icon': 'local_cafe',
        'color': '#C87941',
        'isDefault': 0,
        'sortOrder': 0,
        'createdAt': '2026-01-01T00:00:00.000',
      });
      await db.insert('transactions', {
        'id': 'tx1',
        'type': 'expense',
        'amount': 45000,
        'categoryId': 'cat1',
        'date': '2026-07-01',
        'note': null,
        'recurringId': null,
        'createdAt': '2026-07-01T00:00:00.000',
        'updatedAt': '2026-07-01T00:00:00.000',
      });

      // Replay the real upgrade path a v1 install actually takes to reach
      // v3 — v2 then v3, in order.
      await Migrations.v2(db);
      await Migrations.v3(db);

      final accounts = await db.query('accounts');
      expect(accounts, hasLength(1));
      expect(accounts.first['id'], 'account_default');
      expect(accounts.first['name'], 'My Wallet');

      final transactions = await db.query('transactions');
      expect(transactions, hasLength(1));
      expect(
        transactions.first['accountId'],
        'account_default',
        reason: 'ALTER TABLE ... DEFAULT should backfill every existing row',
      );
      expect(transactions.first['isTransfer'], 0);

      final transferCategory = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: ['system_transfer'],
      );
      expect(transferCategory, hasLength(1));
      expect(transferCategory.first['isSystem'], 1);

      // The pre-existing category must be untouched aside from the new
      // nullable/defaulted columns.
      final coffee = await db.query('categories', where: "id = 'cat1'");
      expect(coffee.first['name'], 'Coffee');
      expect(coffee.first['isSystem'], 0);
      expect(coffee.first['parentId'], isNull);

      await db.close();
    },
  );

  test(
    'migrating a populated v3 database to v4 rebuilds budgets with the new '
    'scope/period/rollover shape, preserving every row and its category link',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createV1Schema,
          // The real app runs with foreign_keys ON (see DatabaseHelper),
          // which makes `DROP TABLE budgets` inside v4 implicitly cascade
          // into budget_categories rows that reference it. Without this,
          // the test passes even if v4 silently wipes every category link.
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      await db.insert('categories', {
        'id': 'cat1',
        'name': 'Food',
        'type': 'expense',
        'icon': 'restaurant',
        'color': '#C87941',
        'isDefault': 0,
        'sortOrder': 0,
        'createdAt': '2026-01-01T00:00:00.000',
      });
      // Insert directly into the original v1-shaped budgets table (the
      // schema Migrations.v4 actually receives before it runs).
      await db.insert('budgets', {
        'id': 'budget1',
        'categoryId': 'cat1',
        'amount': 500000,
        'isActive': 1,
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      });

      // Replay the real upgrade path: v2 -> v3 -> v4, in order.
      await Migrations.v2(db);
      await Migrations.v3(db);
      await Migrations.v4(db);

      final budgets = await db.query('budgets');
      expect(budgets, hasLength(1), reason: 'the existing budget row must survive the rebuild');
      expect(budgets.first['id'], 'budget1');
      expect(budgets.first['amount'], 500000);
      expect(budgets.first['isActive'], 1);
      // New columns default to today's behavior — nothing changes for an
      // existing user until they opt into the new budget shape.
      expect(budgets.first['period'], 'monthly');
      expect(budgets.first['rolloverMode'], 'none');
      expect(budgets.first['scope'], 'category');
      expect(budgets.first['name'], isNull);
      // The old categoryId column must be gone from the rebuilt table —
      // category membership now lives only in budget_categories.
      expect(budgets.first.containsKey('categoryId'), isFalse);

      final links = await db.query('budget_categories');
      expect(links, hasLength(1));
      expect(links.first['budgetId'], 'budget1');
      expect(links.first['categoryId'], 'cat1');

      await db.close();
    },
  );

  test(
    'migrating a populated v4 database to v5 adds goals/debts tables, '
    'goalId/debtId columns, and seeds the goal/debt default categories',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(version: 1, onCreate: _createV1Schema),
      );
      await db.insert('categories', {
        'id': 'cat1',
        'name': 'Food',
        'type': 'expense',
        'icon': 'restaurant',
        'color': '#C87941',
        'isDefault': 0,
        'sortOrder': 0,
        'createdAt': '2026-01-01T00:00:00.000',
      });
      await db.insert('transactions', {
        'id': 'tx1',
        'type': 'expense',
        'amount': 45000,
        'categoryId': 'cat1',
        'date': '2026-07-01',
        'note': null,
        'recurringId': null,
        'createdAt': '2026-07-01T00:00:00.000',
        'updatedAt': '2026-07-01T00:00:00.000',
      });

      // Replay the real upgrade path: v2 -> v3 -> v4 -> v5, in order.
      await Migrations.v2(db);
      await Migrations.v3(db);
      await Migrations.v4(db);
      await Migrations.v5(db);

      // The pre-existing transaction survives with the new columns present
      // (and null, since it predates goals/debts entirely).
      final transactions = await db.query('transactions', where: "id = 'tx1'");
      expect(transactions, hasLength(1));
      expect(transactions.first['goalId'], isNull);
      expect(transactions.first['debtId'], isNull);

      // goals/debts tables exist and are empty on a fresh upgrade.
      expect(await db.query('goals'), isEmpty);
      expect(await db.query('debts'), isEmpty);

      // The three seeded default categories are present with the right type.
      final savings = await db.query('categories', where: "id = 'default_savings_goals'");
      expect(savings, hasLength(1));
      expect(savings.first['type'], 'expense');

      final debtPayments = await db.query('categories', where: "id = 'default_debt_payments'");
      expect(debtPayments, hasLength(1));
      expect(debtPayments.first['type'], 'expense');

      final debtRepayments = await db.query('categories', where: "id = 'default_debt_repayments'");
      expect(debtRepayments, hasLength(1));
      expect(debtRepayments.first['type'], 'income');

      await db.close();
    },
  );

  test(
    'migrating a populated v5 database to v6 adds the subscription columns '
    'to recurring_transactions, defaulting existing templates to '
    'not-a-subscription and not-paused',
    () async {
      final db = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(version: 1, onCreate: _createV1Schema),
      );
      await db.insert('categories', {
        'id': 'cat1',
        'name': 'Bills & Utilities',
        'type': 'expense',
        'icon': 'receipt_long',
        'color': '#D4A05A',
        'isDefault': 0,
        'sortOrder': 0,
        'createdAt': '2026-01-01T00:00:00.000',
      });
      // Insert directly into the original v1-shaped recurring_transactions
      // table (the schema Migrations.v6 actually receives before it runs).
      await db.insert('recurring_transactions', {
        'id': 'rec1',
        'type': 'expense',
        'amount': 150000,
        'categoryId': 'cat1',
        'note': 'Internet',
        'frequency': 'monthly',
        'startDate': '2026-01-05',
        'endDate': null,
        'lastRunDate': '2026-07-05',
        'isActive': 1,
        'createdAt': '2026-01-05T00:00:00.000',
      });

      // Replay the real upgrade path: v2 -> v3 -> v4 -> v5 -> v6, in order.
      await Migrations.v2(db);
      await Migrations.v3(db);
      await Migrations.v4(db);
      await Migrations.v5(db);
      await Migrations.v6(db);

      final recurring = await db.query('recurring_transactions', where: "id = 'rec1'");
      expect(recurring, hasLength(1), reason: 'the existing template must survive the upgrade');
      expect(recurring.first['note'], 'Internet');
      expect(recurring.first['merchant'], isNull);
      // New columns default to today's behavior — an existing recurring
      // template isn't retroactively treated as a tracked subscription.
      expect(recurring.first['isSubscription'], 0);
      expect(recurring.first['isPaused'], 0);
      expect(recurring.first['reminderDaysBefore'], isNull);

      await db.close();
    },
  );

  group('v8 — the Donation category', () {
    Future<Database> upgradedToV7() async {
      final db = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createV1Schema,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      await db.insert('categories', {
        'id': 'cat1',
        'name': 'Coffee',
        'type': 'expense',
        'icon': 'local_cafe',
        'color': '#C87941',
        'isDefault': 0,
        'sortOrder': 0,
        'createdAt': '2026-01-01T00:00:00.000',
      });
      await Migrations.v2(db);
      await Migrations.v3(db);
      await Migrations.v4(db);
      await Migrations.v5(db);
      await Migrations.v6(db);
      await Migrations.v7(db);
      return db;
    }

    test('adds Donation to an existing install without touching user rows',
        () async {
      final db = await upgradedToV7();

      expect(
        await db.query('categories', where: "name = 'Donation'"),
        isEmpty,
        reason: 'nothing should have seeded it before v8 runs',
      );

      await Migrations.v8(db);

      final donation = await db.query('categories', where: "id = 'default_donation'");
      expect(donation, hasLength(1));
      expect(donation.first['name'], 'Donation');
      expect(donation.first['type'], 'expense');
      expect(donation.first['icon'], 'volunteer_activism');
      expect(donation.first['isDefault'], 1);
      expect(donation.first['isSystem'], 0, reason: 'it is a normal, pickable category');
      expect(donation.first['isArchived'], 0);
      // Right after "Other" (8) and ahead of the goal/debt categories.
      expect(donation.first['sortOrder'], 9);

      final coffee = await db.query('categories', where: "id = 'cat1'");
      expect(coffee, hasLength(1), reason: 'the user category must survive');
      expect(coffee.first['name'], 'Coffee');

      await db.close();
    });

    test('replaying the migration does not duplicate the row', () async {
      // A user who upgrades, then reinstalls over the same database, must
      // not end up with two Donation categories.
      final db = await upgradedToV7();
      await Migrations.v8(db);
      await Migrations.v8(db);

      expect(
        await db.query('categories', where: "id = 'default_donation'"),
        hasLength(1),
      );

      await db.close();
    });

    test('a user edit to the category survives a replay', () async {
      final db = await upgradedToV7();
      await Migrations.v8(db);
      await db.update(
        'categories',
        {'name': 'Charity', 'isArchived': 1},
        where: "id = 'default_donation'",
      );

      await Migrations.v8(db);

      final row = await db.query('categories', where: "id = 'default_donation'");
      expect(row.first['name'], 'Charity');
      expect(row.first['isArchived'], 1);

      await db.close();
    });
  });

  group('v9 — the isRecurring flag on budgets', () {
    /// A v1 install replayed all the way to v8, with one budget already
    /// created — the state a real upgrading user is in.
    Future<Database> upgradedToV8() async {
      final db = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _createV1Schema,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      await db.insert('categories', {
        'id': 'cat1',
        'name': 'Groceries',
        'type': 'expense',
        'icon': 'shopping_cart',
        'color': '#C87941',
        'isDefault': 0,
        'sortOrder': 0,
        'createdAt': '2026-01-01T00:00:00.000',
      });
      // The v1-shaped budgets table, i.e. what v4 rebuilds from.
      await db.insert('budgets', {
        'id': 'budget1',
        'categoryId': 'cat1',
        'amount': 750000,
        'isActive': 1,
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      });
      await Migrations.v2(db);
      await Migrations.v3(db);
      await Migrations.v4(db);
      await Migrations.v5(db);
      await Migrations.v6(db);
      await Migrations.v7(db);
      await Migrations.v8(db);
      return db;
    }

    Future<Set<String>> budgetColumns(Database db) async {
      final info = await db.rawQuery('PRAGMA table_info(budgets)');
      return info.map((c) => c['name'] as String).toSet();
    }

    test('backfills every existing budget as recurring', () async {
      final db = await upgradedToV8();

      expect(
        await budgetColumns(db),
        isNot(contains('isRecurring')),
        reason: 'the column should not exist before v9 runs',
      );

      await Migrations.v9(db);

      final budgets = await db.query('budgets');
      expect(budgets, hasLength(1));
      // The load-bearing assertion: budgets shipped before v9 have always
      // re-applied every period, so they must come out of the migration
      // recurring. A 0 here would silently expire them at the next payday.
      expect(budgets.first['isRecurring'], 1);

      await db.close();
    });

    test('preserves the rest of the budget row and its category links', () async {
      final db = await upgradedToV8();
      await Migrations.v9(db);

      final budget = (await db.query('budgets', where: "id = 'budget1'")).first;
      expect(budget['amount'], 750000);
      expect(budget['period'], 'monthly');
      expect(budget['rolloverMode'], 'none');
      expect(budget['scope'], 'category');
      expect(budget['isActive'], 1);
      expect(budget['createdAt'], '2026-01-01T00:00:00.000');

      final links = await db.query('budget_categories', where: "budgetId = 'budget1'");
      expect(links, hasLength(1));
      expect(links.first['categoryId'], 'cat1');

      await db.close();
    });

    test('a fresh install has the same budgets columns as an upgraded one', () async {
      final upgraded = await upgradedToV8();
      await Migrations.v9(upgraded);

      final fresh = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(Migrations.createBudgetsTable);
          },
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        ),
      );

      expect(await budgetColumns(fresh), await budgetColumns(upgraded));

      await upgraded.close();
      await fresh.close();
    });

    test('a fresh install defaults the column to 1', () async {
      // createBudgetsTable and the ALTER must agree on the default, or a
      // budget inserted without the field would mean different things
      // depending on how the database was created.
      final db = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(Migrations.createBudgetsTable);
          },
        ),
      );
      await db.insert('budgets', {
        'id': 'b1',
        'amount': 100,
        'isActive': 1,
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-01T00:00:00.000',
      });

      expect((await db.query('budgets')).first['isRecurring'], 1);

      await db.close();
    });
  });
}
