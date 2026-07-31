# SQLite Database Migration Guide

When you upload your app to the Google Play Store or Apple App Store, users will receive updates over the air. During an update, the app binary is replaced, but the **internal data directory** (where your SQLite database and `SharedPreferences` live) remains untouched.

This means user data is safe by default. **However, if you need to change the structure of your database in a future update**, you must implement a migration strategy. If you alter a table structure in your code without telling SQLite how to transition the old table to the new structure, the app will crash and data could become inaccessible.

Here is how you mitigate that issue and safely handle database migrations using `sqflite`.

## The Golden Rule of Migrations
> [!CAUTION]
> **Never use `DROP TABLE` in a production app update.** Dropping a table will permanently delete all the users' data stored in that table. Always use `ALTER TABLE` to add new columns, or create a temporary table to migrate data if complex changes are needed.

## Step 1: Increment the Database Version
Whenever you change your database schema (e.g., adding a new column, creating a new table), you must increment your `dbVersion` integer.

```dart
// OLD:
// static const int _dbVersion = 1;

// NEW:
static const int _dbVersion = 2; 
```

## Step 2: Implement the `onUpgrade` Callback
When you open your database, `sqflite` compares the version stored on the device with the version defined in your code. If the code version is higher, it triggers the `onUpgrade` callback. 

This is where you write your migration scripts. 

### Example: Adding a new column to an existing table
Imagine in Version 2, we want to add an `image_path` column to our `transactions` table so users can attach receipt photos.

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static const String _dbName = 'finta.db';
  
  // 1. We bumped this from 1 to 2
  static const int _dbVersion = 2; 
  
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // 2. Add the onUpgrade callback
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // This only runs for BRAND NEW installs
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        amount REAL,
        note TEXT,
        image_path TEXT -- New installs get the column immediately
      )
    ''');
  }

  // 3. Handle the upgrade path for existing users
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Use sequential if-statements without 'break' or 'else'
    // so that a user upgrading from v1 to v3 runs through all intermediate migrations.
    
    if (oldVersion < 2) {
      // User is upgrading from v1 to v2 (or higher)
      // Add the new column safely without dropping data
      await db.execute('ALTER TABLE transactions ADD COLUMN image_path TEXT;');
    }
    
    if (oldVersion < 3) {
      // Future upgrade (e.g., from v2 to v3)
      // await db.execute('CREATE TABLE new_feature_table(...)');
    }
  }
}
```

> [!TIP]
> **Why `if (oldVersion < X)`?** 
> If a user stops using the app at Version 1, and then updates to Version 3 a year later, they will skip Version 2. By using sequential `if` blocks, their database will first be upgraded to V2, and then upgraded to V3 sequentially, ensuring no steps are missed.

## Step 3: Test Your Migrations
Before publishing an update that changes the database schema, test it thoroughly:
1. Install the **old** version of your app (from the App Store or an old branch).
2. Add some dummy data (transactions, budgets).
3. Install the **new** version of your app over the old one (using `flutter install` or running from your IDE).
4. Verify that the app opens, the old data is still there, and the new database features work correctly.
