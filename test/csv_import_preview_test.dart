import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/services/csv_import_service.dart';
import 'package:finta/core/utils/csv_import_preview.dart';

ParsedImportRow row({
  required String type,
  String? categoryName,
  int rowNumber = 1,
}) => ParsedImportRow(
  rowNumber: rowNumber,
  date: DateTime(2026, 2, 12),
  amount: 1000,
  type: type,
  categoryName: categoryName,
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
}
