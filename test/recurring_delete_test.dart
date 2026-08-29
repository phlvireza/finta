import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// What stopping a recurring template does to the occurrences it already
/// posted.
///
/// `DatabaseHelper` is a real singleton bound to the on-disk database path, so
/// `RecurringRepository` isn't test-injectable — as in goal_debt_delete_test
/// .dart, these tests pin the exact statements the repository issues against
/// an in-memory database.
///
/// The bug these lock down: stopping a template used to deactivate the
/// template and stop there. `TransactionModel.isRecurring` is just
/// `recurringId != null`, so every occurrence kept drawing the repeat badge,
/// pointing at a schedule that every screen filters out on `isActive` — one
/// the user could no longer see, pause or resume. And because
/// `transactions.recurringId` carries no foreign key, nothing in the schema
/// would catch the stop going half-done.
///
/// The other half matters just as much: the occurrences themselves must
/// survive. Unlike a goal created by mistake, a subscription charge is money
/// that really left the account, so the link goes and the row stays.
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
    CREATE TABLE recurring_transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      frequency TEXT NOT NULL,
      startDate TEXT NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1,
      isSubscription INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      accountId TEXT NOT NULL,
      merchant TEXT,
      date TEXT NOT NULL,
      recurringId TEXT
    )
  ''');
  // The partial unique index that makes generation idempotent. Recreated here
  // because unlinking sets several rows to NULL at once, and it must not
  // collide — NULLs are outside a partial index with this WHERE clause.
  await db.execute(
    'CREATE UNIQUE INDEX idx_recurring_occurrence '
    'ON transactions(recurringId, date) WHERE recurringId IS NOT NULL',
  );
  return db;
}

// --- The repository's statements, verbatim. ---

Future<void> deleteRecurring(Database db, String id) {
  return db.transaction((txn) async {
    await txn.update(
      'transactions',
      {'recurringId': null},
      where: 'recurringId = ?',
      whereArgs: [id],
    );
    await txn.update(
      'recurring_transactions',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  });
}

Future<void> hardDeleteRecurring(Database db, String id) {
  return db.transaction((txn) async {
    await txn.update(
      'transactions',
      {'recurringId': null},
      where: 'recurringId = ?',
      whereArgs: [id],
    );
    await txn.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  });
}

/// What the repeat badge on a transaction row resolves to:
/// `TransactionModel.isRecurring`, which is `recurringId != null`.
Future<bool> showsRecurringBadge(Database db, String txId) async {
  final rows = await db.query(
    'transactions',
    columns: ['recurringId'],
    where: 'id = ?',
    whereArgs: [txId],
  );
  return rows.first['recurringId'] != null;
}

Future<List<String>> transactionIds(Database db) async {
  final rows = await db.query('transactions', columns: ['id'], orderBy: 'id');
  return rows.map((r) => r['id'] as String).toList();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  const spotify = 'rec-spotify';
  const netflix = 'rec-netflix';
  const account = 'acc-main';

  setUp(() async {
    db = await _openTestDb();

    await db.insert('recurring_transactions', {
      'id': spotify,
      'type': 'expense',
      'amount': 54000,
      'frequency': 'monthly',
      'startDate': '2026-01-07',
      'isActive': 1,
      'isSubscription': 1,
    });
    await db.insert('recurring_transactions', {
      'id': netflix,
      'type': 'expense',
      'amount': 65000,
      'frequency': 'monthly',
      'startDate': '2026-01-05',
      'isActive': 1,
      'isSubscription': 1,
    });

    // Two charges from each template, plus one ordinary expense that belongs
    // to no schedule at all.
    for (final row in [
      {'id': 'tx-spotify-jan', 'date': '2026-01-07', 'rec': spotify, 'm': 'Spotify'},
      {'id': 'tx-spotify-feb', 'date': '2026-02-07', 'rec': spotify, 'm': 'Spotify'},
      {'id': 'tx-netflix-jan', 'date': '2026-01-05', 'rec': netflix, 'm': 'Netflix'},
      {'id': 'tx-netflix-feb', 'date': '2026-02-05', 'rec': netflix, 'm': 'Netflix'},
      {'id': 'tx-groceries', 'date': '2026-02-09', 'rec': null, 'm': 'Alfamart'},
    ]) {
      await db.insert('transactions', {
        'id': row['id'],
        'type': 'expense',
        'amount': 54000,
        'accountId': account,
        'merchant': row['m'],
        'date': row['date'],
        'recurringId': row['rec'],
      });
    }
  });

  tearDown(() async => db.close());

  group('delete — stopping a template', () {
    test('drops the repeat badge from every charge it posted', () async {
      expect(await showsRecurringBadge(db, 'tx-spotify-jan'), isTrue);

      await deleteRecurring(db, spotify);

      expect(await showsRecurringBadge(db, 'tx-spotify-jan'), isFalse);
      expect(await showsRecurringBadge(db, 'tx-spotify-feb'), isFalse);
    });

    test('leaves another template\'s charges linked', () async {
      await deleteRecurring(db, spotify);

      expect(await showsRecurringBadge(db, 'tx-netflix-jan'), isTrue);
      expect(await showsRecurringBadge(db, 'tx-netflix-feb'), isTrue);
    });

    test('keeps the charges themselves', () async {
      // The money really left the account — unlinking must not become a
      // delete, or stopping a subscription would silently rewrite balances.
      await deleteRecurring(db, spotify);

      expect(await transactionIds(db), [
        'tx-groceries',
        'tx-netflix-feb',
        'tx-netflix-jan',
        'tx-spotify-feb',
        'tx-spotify-jan',
      ]);

      final rows = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: ['tx-spotify-jan'],
      );
      expect(rows.first['amount'], 54000);
      expect(rows.first['date'], '2026-01-07');
      expect(rows.first['accountId'], account);
      // Backfilled off the template by v10; it has to outlive the link.
      expect(rows.first['merchant'], 'Spotify');
    });

    test('deactivates the template without erasing it', () async {
      await deleteRecurring(db, spotify);

      final rows = await db.query(
        'recurring_transactions',
        where: 'id = ?',
        whereArgs: [spotify],
      );
      expect(rows, hasLength(1));
      expect(rows.first['isActive'], 0);
    });

    test('leaves the other template active', () async {
      await deleteRecurring(db, spotify);

      final rows = await db.query(
        'recurring_transactions',
        where: 'id = ?',
        whereArgs: [netflix],
      );
      expect(rows.first['isActive'], 1);
    });

    test('unlinking several charges at once does not trip the '
        'occurrence index', () async {
      // The (recurringId, date) unique index is partial — NULL rows sit
      // outside it — so two charges can be nulled in the same statement.
      await deleteRecurring(db, spotify);

      final nulled = await db.query(
        'transactions',
        where: 'recurringId IS NULL',
      );
      expect(nulled, hasLength(3)); // both Spotify charges + the groceries
    });

    test('a template with no charges yet still stops cleanly', () async {
      await db.insert('recurring_transactions', {
        'id': 'rec-unused',
        'type': 'expense',
        'amount': 10000,
        'frequency': 'weekly',
        'startDate': '2026-03-01',
        'isActive': 1,
        'isSubscription': 0,
      });

      await deleteRecurring(db, 'rec-unused');

      final rows = await db.query(
        'recurring_transactions',
        where: 'id = ?',
        whereArgs: ['rec-unused'],
      );
      expect(rows.first['isActive'], 0);
      expect(await transactionIds(db), hasLength(5));
    });
  });

  group('hardDelete — erasing a template', () {
    test('unlinks its charges before the row disappears', () async {
      // More urgent than in delete: the id would otherwise resolve to no row
      // at all, so nothing could ever explain the badge.
      await hardDeleteRecurring(db, spotify);

      expect(await showsRecurringBadge(db, 'tx-spotify-jan'), isFalse);
      expect(await showsRecurringBadge(db, 'tx-spotify-feb'), isFalse);
    });

    test('keeps the charges and the other template', () async {
      await hardDeleteRecurring(db, spotify);

      expect(await transactionIds(db), hasLength(5));
      expect(await showsRecurringBadge(db, 'tx-netflix-jan'), isTrue);
    });

    test('removes the template row', () async {
      await hardDeleteRecurring(db, spotify);

      final rows = await db.query(
        'recurring_transactions',
        where: 'id = ?',
        whereArgs: [spotify],
      );
      expect(rows, isEmpty);
    });
  });
}
