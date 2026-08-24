import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:finta/repositories/transaction_repository.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onCreate: (database, _) => database.execute(
          'CREATE TABLE transactions ('
          'id TEXT PRIMARY KEY, '
          'isTransfer INTEGER NOT NULL DEFAULT 0'
          ')',
        ),
        version: 1,
      ),
    );
  });

  tearDown(() => db.close());

  Future<bool> hasAny() async {
    final result = await db.rawQuery(
      TransactionRepository.hasAnyNonTransferQuery,
    );
    return (result.first['hasAny'] as num) != 0;
  }

  test(
    'empty and transfer-only ledgers are not genuine transaction history',
    () async {
      expect(await hasAny(), isFalse);
      await db.insert('transactions', {'id': 'transfer-leg', 'isTransfer': 1});
      expect(await hasAny(), isFalse);
    },
  );

  test(
    'a non-transfer row makes the ledger non-empty until it is deleted',
    () async {
      await db.insert('transactions', {'id': 'transaction', 'isTransfer': 0});
      expect(await hasAny(), isTrue);
      await db.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: ['transaction'],
      );
      expect(await hasAny(), isFalse);
    },
  );
}
