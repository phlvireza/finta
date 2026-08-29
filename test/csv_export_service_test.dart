import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/database/seed_data.dart';
import 'package:finta/core/services/csv_export_service.dart';
import 'package:finta/core/services/csv_import_service.dart';
import 'package:finta/models/transaction_model.dart';

TransactionModel tx({
  required String type,
  required double amount,
  required DateTime date,
  String categoryId = 'cat1',
  String accountId = 'acc1',
  String? note,
  String? transferId,
  bool isTransfer = false,
}) => TransactionModel(
  id: 'tx-${date.millisecondsSinceEpoch}-$amount-$accountId-$type',
  type: type,
  amount: amount,
  categoryId: categoryId,
  accountId: accountId,
  transferId: transferId,
  isTransfer: isTransfer,
  date: date,
  note: note,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// The two rows the app writes for one transfer.
List<TransactionModel> transferLegs({
  required String from,
  required String to,
  required double amount,
  required DateTime date,
  String transferId = 'tr1',
  String? note,
}) => [
  tx(
    type: 'expense',
    amount: amount,
    date: date,
    categoryId: SeedData.transferCategoryId,
    accountId: from,
    transferId: transferId,
    isTransfer: true,
    note: note,
  ),
  tx(
    type: 'income',
    amount: amount,
    date: date,
    categoryId: SeedData.transferCategoryId,
    accountId: to,
    transferId: transferId,
    isTransfer: true,
    note: note,
  ),
];

/// The importer's auto-detected mapping for Squirio's own header:
/// Date,Type,Amount,Category,Account,To Account,Merchant,Note
const ownFormat = CsvColumnMapping(
  date: 0,
  type: 1,
  amount: 2,
  category: 3,
  account: 4,
  toAccount: 5,
  merchant: 6,
  note: 7,
);

void main() {
  final export = CsvExportService();
  final import = CsvImportService();

  String categoryName(String id) => switch (id) {
    'cat1' => 'Groceries',
    'cat2' => 'Salary',
    SeedData.transferCategoryId => 'Transfer',
    _ => 'Unknown',
  };
  String accountName(String id) => switch (id) {
    'acc1' => 'BCA',
    'acc2' => 'Cash Wallet',
    _ => 'Unknown',
  };

  group('buildCsv', () {
    test('writes the header the importer auto-detects', () {
      final csv = export.buildCsv(const [], categoryName, accountName);

      // Not UI copy: translating this would break column auto-detection for
      // a user re-importing their own export in Indonesian.
      expect(
        csv.trim(),
        'Date,Type,Amount,Category,Account,To Account,Merchant,Note',
      );
      expect(
        CsvExportService.header,
        'Date,Type,Amount,Category,Account,To Account,Merchant,Note',
      );
    });

    test('writes dates as bare ISO days, not full timestamps', () {
      final csv = export.buildCsv(
        [
          tx(
            type: 'expense',
            amount: 25000,
            date: DateTime(2026, 2, 9, 13, 45),
          ),
        ],
        categoryName,
        accountName,
      );

      expect(csv, contains('2026-02-09,expense,25000.0,Groceries,BCA,,,'));
    });

    test('names the account each ordinary row belongs to', () {
      final csv = export.buildCsv(
        [
          tx(
            type: 'income',
            amount: 8500000,
            date: DateTime(2026, 2, 1),
            categoryId: 'cat2',
            accountId: 'acc2',
          ),
        ],
        categoryName,
        accountName,
      );

      expect(csv, contains(',Salary,Cash Wallet,,,'));
    });
  });

  group('transfers', () {
    test('a pair collapses to one row naming both accounts', () {
      final csv = export.buildCsv(
        transferLegs(
          from: 'acc2',
          to: 'acc1',
          amount: 500000,
          date: DateTime(2026, 2, 12),
        ),
        categoryName,
        accountName,
      );
      final rows = csv.trim().split('\n').skip(1).toList();

      expect(rows, hasLength(1), reason: 'two legs, one row');
      expect(
        rows.single,
        '2026-02-12,transfer,500000.0,Transfer,Cash Wallet,BCA,,',
      );
    });

    test('source is the expense leg however the legs are ordered', () {
      // getAll orders by date then createdAt, so the income leg can come
      // first. Direction must come from the legs' types, not their position.
      final legs = transferLegs(
        from: 'acc2',
        to: 'acc1',
        amount: 500000,
        date: DateTime(2026, 2, 12),
      ).reversed.toList();

      final csv = export.buildCsv(legs, categoryName, accountName);

      expect(csv, contains(',transfer,500000.0,Transfer,Cash Wallet,BCA,,'));
    });

    test('an orphan leg is still exported, as an ordinary row', () {
      // Should not happen, but dropping a row silently would lose money from
      // the ledger. Export it as the plain type it carries instead.
      final csv = export.buildCsv(
        [
          tx(
            type: 'expense',
            amount: 500000,
            date: DateTime(2026, 2, 12),
            categoryId: SeedData.transferCategoryId,
            accountId: 'acc2',
            transferId: 'tr-orphan',
            isTransfer: true,
          ),
        ],
        categoryName,
        accountName,
      );
      final rows = csv.trim().split('\n').skip(1).toList();

      expect(rows, hasLength(1));
      expect(rows.single, startsWith('2026-02-12,expense,500000.0,Transfer,'));
    });

    test('does not disturb ordinary rows around it', () {
      final csv = export.buildCsv(
        [
          tx(type: 'expense', amount: 85000, date: DateTime(2026, 2, 10)),
          ...transferLegs(
            from: 'acc2',
            to: 'acc1',
            amount: 500000,
            date: DateTime(2026, 2, 12),
          ),
          tx(
            type: 'income',
            amount: 8500000,
            date: DateTime(2026, 2, 13),
            categoryId: 'cat2',
          ),
        ],
        categoryName,
        accountName,
      );
      final rows = csv.trim().split('\n').skip(1).toList();

      expect(rows, hasLength(3));
      expect(rows[0], contains('expense,85000.0'));
      expect(rows[1], contains('transfer,500000.0'));
      expect(rows[2], contains('income,8500000.0'));
    });
  });

  group('csvField', () {
    test('leaves an ordinary value unquoted', () {
      expect(CsvExportService.csvField('Groceries'), 'Groceries');
    });

    test('quotes a value containing a comma', () {
      expect(CsvExportService.csvField('Food, drink'), '"Food, drink"');
    });

    test('quotes a value containing a newline', () {
      expect(CsvExportService.csvField('two\nlines'), '"two\nlines"');
    });

    test('doubles an embedded quote', () {
      expect(CsvExportService.csvField('say "hi"'), '"say ""hi"""');
    });
  });

  group('round trip', () {
    test('an export re-imports to the same transactions', () {
      final transactions = [
        tx(type: 'expense', amount: 85000, date: DateTime(2026, 2, 12)),
        tx(
          type: 'income',
          amount: 8500000,
          date: DateTime(2026, 2, 1),
          categoryId: 'cat2',
          accountId: 'acc2',
        ),
      ];

      final parsed = import.parse(
        export.buildCsv(transactions, categoryName, accountName),
      );
      final result = import.mapRows(parsed.dataRows, ownFormat);

      expect(result.errors, isEmpty);
      expect(result.rows.map((r) => r.date), [
        DateTime(2026, 2, 12),
        DateTime(2026, 2, 1),
      ]);
      expect(result.rows.map((r) => r.amount), [85000, 8500000]);
      expect(result.rows.map((r) => r.type), ['expense', 'income']);
      expect(result.rows.map((r) => r.categoryName), ['Groceries', 'Salary']);
      expect(result.rows.map((r) => r.accountName), ['BCA', 'Cash Wallet']);
    });

    test('a transfer survives the round trip as a transfer', () {
      // The reported bug: a wallet-to-wallet transfer came back as an
      // ordinary expense and income, which every income/expense aggregate
      // then counted.
      final parsed = import.parse(
        export.buildCsv(
          transferLegs(
            from: 'acc2',
            to: 'acc1',
            amount: 500000,
            date: DateTime(2026, 2, 12),
            note: 'Top up',
          ),
          categoryName,
          accountName,
        ),
      );
      final result = import.mapRows(parsed.dataRows, ownFormat);

      expect(result.errors, isEmpty);
      final row = result.rows.single;
      expect(row.isTransfer, isTrue);
      expect(row.type, 'transfer');
      expect(row.accountName, 'Cash Wallet');
      expect(row.toAccountName, 'BCA');
      expect(row.amount, 500000);
      expect(row.note, 'Top up');
    });

    test('a note containing a comma survives the round trip intact', () {
      // The case unquoted output would silently corrupt: the note would
      // split across columns and shift Category out of position.
      final parsed = import.parse(
        export.buildCsv(
          [
            tx(
              type: 'expense',
              amount: 42000,
              date: DateTime(2026, 2, 12),
              note: 'lunch, coffee',
            ),
          ],
          categoryName,
          accountName,
        ),
      );
      final result = import.mapRows(parsed.dataRows, ownFormat);

      expect(result.errors, isEmpty);
      expect(result.rows.single.note, 'lunch, coffee');
      expect(result.rows.single.categoryName, 'Groceries');
    });
  });

  group('backward compatibility', () {
    test('an export in the old five-column format still imports', () {
      // Files produced before accounts were carried. The two new columns go
      // unmapped, every row falls back to the account the user picks, and
      // nothing errors.
      const old =
          'Date,Type,Amount,Category,Note\n'
          '2026-02-12,expense,85000,Groceries,lunch\n'
          '2026-02-13,income,8500000,Salary,\n';
      final parsed = import.parse(old);
      const mapping = CsvColumnMapping(
        date: 0,
        type: 1,
        amount: 2,
        category: 3,
        note: 4,
      );
      final result = import.mapRows(parsed.dataRows, mapping);

      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(2));
      expect(result.rows.every((r) => r.accountName == null), isTrue);
      expect(result.rows.every((r) => !r.isTransfer), isTrue);
    });
  });

  group('transferPairCount', () {
    test('counts pairs, not legs, so it matches the rows written', () {
      // What the export snackbar reports: the ledger holds 30 entries, the
      // file gets 28 rows, and the difference is exactly the two pairs.
      final ledger = [
        for (var i = 0; i < 26; i++)
          tx(type: 'expense', amount: 1000.0 + i, date: DateTime(2026, 2, 12)),
        ...transferLegs(
          from: 'acc1',
          to: 'acc2',
          amount: 500000,
          date: DateTime(2026, 2, 12),
          transferId: 'tr1',
        ),
        ...transferLegs(
          from: 'acc2',
          to: 'acc1',
          amount: 250000,
          date: DateTime(2026, 2, 13),
          transferId: 'tr2',
        ),
      ];

      expect(ledger, hasLength(30));
      expect(CsvExportService.transferPairCount(ledger), 2);
      expect(
        ledger.length - CsvExportService.transferPairCount(ledger),
        _dataRowCount(ledger),
      );
    });

    test('a ledger with no transfers has no pairs', () {
      final ledger = [
        tx(type: 'expense', amount: 1000, date: DateTime(2026, 2, 12)),
      ];

      expect(CsvExportService.transferPairCount(ledger), 0);
      expect(ledger.length, _dataRowCount(ledger));
    });

    test('an orphan leg is not a pair — it is written as an ordinary row', () {
      final ledger = [
        tx(
          type: 'expense',
          amount: 500000,
          date: DateTime(2026, 2, 12),
          categoryId: SeedData.transferCategoryId,
          transferId: 'tr-orphan',
          isTransfer: true,
        ),
      ];

      expect(CsvExportService.transferPairCount(ledger), 0);
      expect(ledger.length, _dataRowCount(ledger));
    });

    test('an empty ledger has no pairs', () {
      expect(CsvExportService.transferPairCount(const []), 0);
    });
  });
}

/// Data rows the export actually writes, so the arithmetic the snackbar does
/// (`ledger.length - transferPairCount`) is checked against the real file
/// rather than restated.
int _dataRowCount(List<TransactionModel> ledger) => CsvExportService()
    .buildCsv(ledger, (id) => 'Category', (id) => 'Wallet')
    .trim()
    .split('\n')
    .length -
    1;
