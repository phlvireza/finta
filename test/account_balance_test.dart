import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:finta/core/database/migrations.dart';

/// Minimal v3-shaped schema (accounts + transactions only — categories
/// aren't needed to exercise balance math) built directly against an
/// in-memory db, mirroring the isolation style of migration_test.dart.
/// `DatabaseHelper` is a real singleton bound to the on-disk database path,
/// so it isn't test-injectable — these tests instead pin the exact
/// invariants `AccountRepository`/`TransactionRepository` rely on: an
/// account's balance is a plain income/expense sum, and reporting
/// aggregates must exclude `isTransfer` rows.
Future<Database> _openTestDb() async {
  final db = await databaseFactoryFfi.openDatabase(':memory:', options: OpenDatabaseOptions(version: 1));
  await db.execute(Migrations.createAccountsTable);
  await db.execute('''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      accountId TEXT NOT NULL,
      isTransfer INTEGER NOT NULL DEFAULT 0,
      date TEXT NOT NULL
    )
  ''');
  return db;
}

Future<Map<String, double>> _getAllBalances(Database db) async {
  final accounts = await db.query('accounts', columns: ['id', 'openingBalance']);
  final sums = await db.rawQuery(
    'SELECT accountId, type, SUM(amount) as total FROM transactions GROUP BY accountId, type',
  );
  final balances = <String, double>{
    for (final a in accounts) a['id'] as String: (a['openingBalance'] as num).toDouble(),
  };
  for (final row in sums) {
    final accountId = row['accountId'] as String?;
    if (accountId == null || !balances.containsKey(accountId)) continue;
    final total = (row['total'] as num).toDouble();
    balances[accountId] = balances[accountId]! + (row['type'] == 'income' ? total : -total);
  }
  return balances;
}

Future<double> _sumExcludingTransfers(Database db, String type) async {
  final result = await db.rawQuery(
    'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = ? AND isTransfer = 0',
    [type],
  );
  return (result.first['total'] as num).toDouble();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> insertAccount(Database db, String id, {double openingBalance = 0}) {
    return db.insert('accounts', {
      'id': id,
      'name': id,
      'type': 'cash',
      'openingBalance': openingBalance,
      'color': '#C87941',
      'isArchived': 0,
      'includeInTotal': 1,
      'sortOrder': 0,
      'createdAt': '2026-01-01T00:00:00.000',
    });
  }

  Future<void> insertTx(
    Database db,
    String id,
    String type,
    double amount,
    String accountId, {
    bool isTransfer = false,
  }) {
    return db.insert('transactions', {
      'id': id,
      'type': type,
      'amount': amount,
      'accountId': accountId,
      'isTransfer': isTransfer ? 1 : 0,
      'date': '2026-07-01',
    });
  }

  test('account balance is opening balance plus income minus expense', () async {
    final db = await _openTestDb();
    await insertAccount(db, 'a1', openingBalance: 100000);
    await insertTx(db, 'tx1', 'income', 50000, 'a1');
    await insertTx(db, 'tx2', 'expense', 20000, 'a1');

    final balances = await _getAllBalances(db);
    expect(balances['a1'], 130000);

    await db.close();
  });

  test('a transfer moves the exact amount between two accounts without leaking', () async {
    final db = await _openTestDb();
    await insertAccount(db, 'from', openingBalance: 100000);
    await insertAccount(db, 'to', openingBalance: 0);

    // A transfer is an expense leg on the source + an income leg on the
    // destination, both isTransfer — exactly what TransactionProvider.
    // addTransfer posts.
    await insertTx(db, 'leg1', 'expense', 30000, 'from', isTransfer: true);
    await insertTx(db, 'leg2', 'income', 30000, 'to', isTransfer: true);

    final balances = await _getAllBalances(db);
    expect(balances['from'], 70000);
    expect(balances['to'], 30000);
    // Net worth (sum of both accounts) is unchanged by the transfer.
    expect(balances['from']! + balances['to']!, 100000);

    await db.close();
  });

  test('income/expense reporting aggregates exclude isTransfer rows', () async {
    final db = await _openTestDb();
    await insertAccount(db, 'a1');
    await insertAccount(db, 'a2');
    await insertTx(db, 'tx1', 'expense', 45000, 'a1'); // real spend
    await insertTx(db, 'leg1', 'expense', 500000, 'a1', isTransfer: true); // transfer out
    await insertTx(db, 'leg2', 'income', 500000, 'a2', isTransfer: true); // transfer in

    final totalExpense = await _sumExcludingTransfers(db, 'expense');
    final totalIncome = await _sumExcludingTransfers(db, 'income');

    expect(totalExpense, 45000, reason: 'the 500k transfer must not count as spending');
    expect(totalIncome, 0, reason: 'the 500k transfer must not count as income');

    await db.close();
  });
}
