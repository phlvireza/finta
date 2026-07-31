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
}
