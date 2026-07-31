import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'seed_data.dart';
import 'migrations.dart';

/// SQLite database singleton — handles initialization, migrations, and seeding.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  /// Bump on every schema change and add a matching `if (oldVersion < n)`
  /// branch in [_onUpgrade] backed by a method on [Migrations]. `_onCreate`
  /// must always produce a schema identical to a v1 install that has
  /// replayed every migration — see test/migration_test.dart.
  static const int dbVersion = 2;

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'finta.db');

    return openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // SQLite defaults this OFF per-connection; our schema declares FKs
        // on categoryId but nothing enforced them until now.
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Sequential, non-exclusive ifs: an install upgrading from v1 straight
    // to v3 (once it exists) replays v2 then v3 in order — nothing skipped.
    if (oldVersion < 2) await Migrations.v2(db);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // Transactions table
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

    // Recurring transactions table
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

    // Budgets table
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

    // Indexes for common queries
    await db.execute(
      'CREATE INDEX idx_transactions_date ON transactions(date)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_type ON transactions(type)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_categoryId ON transactions(categoryId)',
    );
    await Migrations.createRecurringOccurrenceIndex(db);

    // Seed default categories
    await SeedData.seedCategories(db);
  }

  /// Close the database (for testing / cleanup).
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
