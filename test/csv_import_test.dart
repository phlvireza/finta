import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/services/csv_import_service.dart';

void main() {
  final service = CsvImportService();

  group('parse', () {
    test('splits a header row from data rows', () {
      final result = service.parse(
        'Date,Amount,Note\n2026-01-01,45000,Coffee\n',
      );
      expect(result.headers, ['Date', 'Amount', 'Note']);
      expect(result.dataRows, hasLength(1));
      expect(result.dataRows.first, ['2026-01-01', '45000', 'Coffee']);
    });

    test('an empty file produces no headers or rows', () {
      final result = service.parse('');
      expect(result.headers, isEmpty);
      expect(result.dataRows, isEmpty);
    });
  });

  group('mapRows', () {
    const mapping = CsvColumnMapping(
      date: 0,
      amount: 1,
      type: 2,
      category: 3,
      note: 4,
      merchant: 5,
    );

    test('parses a fully-populated row', () {
      final result = service.mapRows([
        [
          '2026-07-15',
          '50000',
          'expense',
          'Food & Drinks',
          'Lunch',
          'Starbucks',
        ],
      ], mapping);
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      final row = result.rows.first;
      expect(row.date, DateTime(2026, 7, 15));
      expect(row.amount, 50000);
      expect(row.type, 'expense');
      expect(row.categoryName, 'Food & Drinks');
      expect(row.note, 'Lunch');
      expect(row.merchant, 'Starbucks');
    });

    test(
      'infers expense from a negative amount when type column is absent',
      () {
        const noTypeMapping = CsvColumnMapping(date: 0, amount: 1);
        final result = service.mapRows([
          ['2026-07-15', '-50000'],
        ], noTypeMapping);
        expect(result.rows.single.type, 'expense');
        expect(
          result.rows.single.amount,
          50000,
          reason: 'stored amount is always positive; sign only decides type',
        );
      },
    );

    test('infers income from a positive amount when type column is absent', () {
      const noTypeMapping = CsvColumnMapping(date: 0, amount: 1);
      final result = service.mapRows([
        ['2026-07-15', '2500000'],
      ], noTypeMapping);
      expect(result.rows.single.type, 'income');
    });

    test('recognizes bank-statement-style debit/credit as expense/income', () {
      final result = service.mapRows([
        ['2026-07-15', '50000', 'debit'],
        ['2026-07-16', '50000', 'credit'],
      ], const CsvColumnMapping(date: 0, amount: 1, type: 2));
      expect(result.rows[0].type, 'expense');
      expect(result.rows[1].type, 'income');
    });

    test(
      'parses parenthesized amounts as negative (common accounting export style)',
      () {
        final result = service.mapRows([
          ['2026-07-15', '(50,000)'],
        ], const CsvColumnMapping(date: 0, amount: 1));
        expect(result.rows.single.type, 'expense');
        expect(result.rows.single.amount, 50000);
      },
    );

    test('accepts day-first and month-first slash dates', () {
      final result = service.mapRows([
        ['31/01/2026', '1000'],
        ['01/31/2026', '1000'],
      ], const CsvColumnMapping(date: 0, amount: 1));
      expect(result.errors, isEmpty);
      expect(result.rows[0].date, DateTime(2026, 1, 31));
      expect(result.rows[1].date, DateTime(2026, 1, 31));
    });

    test('collects a per-row error instead of aborting the whole import', () {
      final result = service.mapRows([
        ['2026-07-15', '50000'],
        ['not-a-date', '50000'],
        ['2026-07-17', 'not-a-number'],
      ], const CsvColumnMapping(date: 0, amount: 1));
      expect(result.rows, hasLength(1));
      expect(result.errors, hasLength(2));
      expect(result.errors[0].rowNumber, 2);
      expect(result.errors[1].rowNumber, 3);
    });

    test('blank category/note/merchant map to null, not empty string', () {
      final result = service.mapRows([
        ['2026-07-15', '50000', '', '', '', ''],
      ], mapping);
      final row = result.rows.single;
      expect(row.categoryName, isNull);
      expect(row.note, isNull);
      expect(row.merchant, isNull);
    });
  });

  group('transfers', () {
    const mapping = CsvColumnMapping(
      date: 0,
      type: 1,
      amount: 2,
      account: 3,
      toAccount: 4,
    );

    test('parses a transfer row with both accounts', () {
      final result = service.mapRows([
        ['2026-02-12', 'transfer', '500000', 'Cash Wallet', 'BCA'],
      ], mapping);

      expect(result.errors, isEmpty);
      final row = result.rows.single;
      expect(row.type, 'transfer');
      expect(row.isTransfer, isTrue);
      expect(row.accountName, 'Cash Wallet');
      expect(row.toAccountName, 'BCA');
    });

    test('rejects a transfer with no destination account', () {
      // Guaranteeing a destination here is what lets the rest of the
      // pipeline treat toAccountName as non-null for transfer rows.
      final result = service.mapRows([
        ['2026-02-12', 'transfer', '500000', 'Cash Wallet', ''],
      ], mapping);

      expect(result.rows, isEmpty);
      expect(result.errors.single.rowNumber, 1);
      expect(result.errors.single.reason, contains('destination'));
    });

    test('one bad transfer does not abort the rows around it', () {
      final result = service.mapRows([
        ['2026-02-10', 'expense', '85000', 'BCA', ''],
        ['2026-02-12', 'transfer', '500000', 'Cash Wallet', ''],
        ['2026-02-13', 'transfer', '250000', 'BCA', 'Jago'],
      ], mapping);

      expect(result.rows.map((r) => r.rowNumber), [1, 3]);
      expect(result.errors.single.rowNumber, 2);
    });

    test('an ordinary row is never inferred to be a transfer', () {
      // Mistaking one for a transfer would hide it from every income and
      // expense total in the app, so only the explicit word counts.
      final result = service.mapRows([
        ['2026-02-12', 'transfers to savings', '500000', 'BCA', 'Jago'],
      ], mapping);

      expect(result.rows.single.isTransfer, isFalse);
    });
  });
}
