import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/services/csv_import_service.dart';
import 'package:finta/core/utils/csv_import_preview.dart';

ParsedImportRow row({
  required String type,
  String? categoryName,
  String? accountName,
  String? toAccountName,
  int rowNumber = 1,
}) => ParsedImportRow(
  rowNumber: rowNumber,
  date: DateTime(2026, 2, 12),
  amount: 1000,
  type: type,
  categoryName: categoryName,
  accountName: accountName,
  toAccountName: toAccountName,
);

ParsedImportRow transferRow({
  String? from,
  String to = 'BCA',
  int rowNumber = 1,
}) => row(
  type: 'transfer',
  accountName: from,
  toAccountName: to,
  rowNumber: rowNumber,
);

void main() {
  group('categoryKey', () {
    test('is case- and whitespace-insensitive, matching _findCategory', () {
      expect(
        categoryKey('expense', '  Groceries '),
        categoryKey('expense', 'groceries'),
      );
    });

    test('separates the same name under a different type', () {
      expect(
        categoryKey('income', 'Bonus'),
        isNot(categoryKey('expense', 'Bonus')),
      );
    });
  });

  group('pendingNewCategories', () {
    test('reports a name the user does not have', () {
      final pending = pendingNewCategories(
        rows: [row(type: 'expense', categoryName: 'Transport')],
        existingKeys: {categoryKey('expense', 'Groceries')},
        fallbackName: 'Imported',
      );

      expect(pending, ['Transport']);
    });

    test('does not report a name the user already has', () {
      final pending = pendingNewCategories(
        rows: [row(type: 'expense', categoryName: 'Groceries')],
        existingKeys: {categoryKey('expense', 'Groceries')},
        fallbackName: 'Imported',
      );

      expect(pending, isEmpty);
    });

    test('still reports a name that exists only under the other type', () {
      // "Bonus" as an expense is a different category from "Bonus" as
      // income, and the import has to create the one it is missing.
      final pending = pendingNewCategories(
        rows: [row(type: 'income', categoryName: 'Bonus')],
        existingKeys: {categoryKey('expense', 'Bonus')},
        fallbackName: 'Imported',
      );

      expect(pending, ['Bonus']);
    });

    test('reports each distinct name once, however many rows use it', () {
      final pending = pendingNewCategories(
        rows: [
          row(type: 'expense', categoryName: 'Transport', rowNumber: 1),
          row(type: 'expense', categoryName: 'Transport', rowNumber: 2),
          row(type: 'expense', categoryName: 'transport', rowNumber: 3),
        ],
        existingKeys: const {},
        fallbackName: 'Imported',
      );

      expect(pending, ['Transport']);
    });

    test('counts the fallback bucket once for the whole file', () {
      // Rows with no category of their own all land in "Imported", so the
      // user is warned about one new category, not one per row.
      final pending = pendingNewCategories(
        rows: [
          row(type: 'expense', rowNumber: 1),
          row(type: 'expense', rowNumber: 2),
        ],
        existingKeys: const {},
        fallbackName: 'Imported',
      );

      expect(pending, ['Imported']);
    });

    test('preserves first-seen order', () {
      final pending = pendingNewCategories(
        rows: [
          row(type: 'expense', categoryName: 'Transport', rowNumber: 1),
          row(type: 'expense', categoryName: 'Coffee', rowNumber: 2),
          row(type: 'expense', categoryName: 'Transport', rowNumber: 3),
        ],
        existingKeys: const {},
        fallbackName: 'Imported',
      );

      expect(pending, ['Transport', 'Coffee']);
    });

    test('an empty file needs no categories', () {
      expect(
        pendingNewCategories(
          rows: const [],
          existingKeys: const {},
          fallbackName: 'Imported',
        ),
        isEmpty,
      );
    });
  });

  group('isNewCategory', () {
    test('agrees with pendingNewCategories on the same input', () {
      final rows = [
        row(type: 'expense', categoryName: 'Groceries', rowNumber: 1),
        row(type: 'expense', categoryName: 'Transport', rowNumber: 2),
        row(type: 'expense', rowNumber: 3),
      ];
      const existing = {'expense:groceries'};

      final flagged = rows
          .where(
            (r) => isNewCategory(
              row: r,
              existingKeys: existing,
              fallbackName: 'Imported',
            ),
          )
          .length;

      // Two rows flagged, two distinct names — the per-row badge and the
      // header summary must not be able to disagree.
      expect(flagged, 2);
      expect(
        pendingNewCategories(
          rows: rows,
          existingKeys: existing,
          fallbackName: 'Imported',
        ),
        ['Transport', 'Imported'],
      );
    });
  });

  group('mapRows row numbers', () {
    test('a parsed row carries the file row it came from', () {
      final service = CsvImportService();
      const mapping = CsvColumnMapping(date: 0, amount: 1);
      // Row 2 fails, so the rows either side must stay numbered 1 and 3 —
      // the preview lists them beside the skipped one.
      final result = service.mapRows([
        ['2026-02-10', '100'],
        ['not a date', '200'],
        ['2026-02-12', '300'],
      ], mapping);

      expect(result.rows.map((r) => r.rowNumber), [1, 3]);
      expect(result.errors.map((e) => e.rowNumber), [2]);
    });
  });

  group('transfers and categories', () {
    test('a transfer row asks for no category', () {
      // Transfers are pinned to the system Transfer category. Counting them
      // here is what made the importer create a duplicate user category
      // called "Transfer" shadowing the system one.
      final pending = pendingNewCategories(
        rows: [transferRow(from: 'Cash')],
        existingKeys: const {},
        fallbackName: 'Imported',
      );

      expect(pending, isEmpty);
    });

    test('a transfer row never carries the new-category badge', () {
      expect(
        isNewCategory(
          row: transferRow(from: 'Cash'),
          existingKeys: const {},
          fallbackName: 'Imported',
        ),
        isFalse,
      );
    });
  });

  group('pendingNewAccounts', () {
    test('reports an account the user does not have', () {
      final pending = pendingNewAccounts(
        rows: [row(type: 'expense', accountName: 'Cash Wallet')],
        existingKeys: {accountKey('BCA')},
        fallbackName: 'BCA',
      );

      expect(pending, ['Cash Wallet']);
    });

    test('does not report one the user already has, whatever the casing', () {
      final pending = pendingNewAccounts(
        rows: [row(type: 'expense', accountName: '  bca ')],
        existingKeys: {accountKey('BCA')},
        fallbackName: 'BCA',
      );

      expect(pending, isEmpty);
    });

    test('covers both ends of a transfer', () {
      final pending = pendingNewAccounts(
        rows: [transferRow(from: 'Cash Wallet', to: 'Jago')],
        existingKeys: const {},
        fallbackName: 'BCA',
      );

      expect(pending, ['Cash Wallet', 'Jago']);
    });

    test(
      'never reports the fallback — the user picked an existing account',
      () {
        final pending = pendingNewAccounts(
          rows: [row(type: 'expense')],
          existingKeys: const {},
          fallbackName: 'BCA',
        );

        expect(pending, isEmpty);
      },
    );

    test('reports each account once, in first-seen order', () {
      final pending = pendingNewAccounts(
        rows: [
          row(type: 'expense', accountName: 'Jago', rowNumber: 1),
          row(type: 'expense', accountName: 'Cash Wallet', rowNumber: 2),
          row(type: 'expense', accountName: 'jago', rowNumber: 3),
        ],
        existingKeys: const {},
        fallbackName: 'BCA',
      );

      expect(pending, ['Jago', 'Cash Wallet']);
    });
  });

  group('transferRowErrors', () {
    test('rejects a transfer whose two ends are the same account', () {
      final errors = transferRowErrors(
        rows: [transferRow(from: 'BCA', to: 'BCA', rowNumber: 4)],
        fallbackName: 'Cash',
      );

      expect(errors.single.rowNumber, 4);
    });

    test('catches the same-account case via the fallback', () {
      // Source blank, so it resolves to the picked account — which is also
      // the destination. Only visible once the fallback is known, which is
      // why this check cannot live in the parser.
      final errors = transferRowErrors(
        rows: [transferRow(from: null, to: 'BCA')],
        fallbackName: 'BCA',
      );

      expect(errors, hasLength(1));
    });

    test('accepts a transfer between two different accounts', () {
      expect(
        transferRowErrors(
          rows: [transferRow(from: 'Cash', to: 'BCA')],
          fallbackName: 'Cash',
        ),
        isEmpty,
      );
    });

    test('ignores ordinary rows', () {
      expect(
        transferRowErrors(
          rows: [row(type: 'expense', accountName: 'BCA')],
          fallbackName: 'BCA',
        ),
        isEmpty,
      );
    });
  });

  group('ledgerEntryCount', () {
    test('a transfer row counts as two ledger entries', () {
      // The reported case: a 28-row file whose ledger grows by 30. The gap is
      // the two transfers, each stored as a linked expense/income pair.
      final rows = [
        for (var i = 0; i < 26; i++)
          row(type: 'expense', categoryName: 'Groceries', rowNumber: i + 1),
        transferRow(from: 'Cash Wallet', to: 'BCA', rowNumber: 27),
        transferRow(from: 'BCA', to: 'Cash Wallet', rowNumber: 28),
      ];

      expect(rows.length, 28);
      expect(transferRowCount(rows), 2);
      expect(ledgerEntryCount(rows), 30);
    });

    test('a file with no transfers writes one entry per row', () {
      final rows = [
        row(type: 'expense', rowNumber: 1),
        row(type: 'income', rowNumber: 2),
      ];

      expect(transferRowCount(rows), 0);
      expect(ledgerEntryCount(rows), rows.length);
    });

    test('a file of nothing but transfers doubles', () {
      final rows = [
        transferRow(from: 'Cash Wallet', to: 'BCA', rowNumber: 1),
        transferRow(from: 'BCA', to: 'Cash Wallet', rowNumber: 2),
      ];

      expect(ledgerEntryCount(rows), 4);
    });

    test('an empty row list produces zero entries', () {
      expect(ledgerEntryCount(const []), 0);
      expect(transferRowCount(const []), 0);
    });
  });
}
