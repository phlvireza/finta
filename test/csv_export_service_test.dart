import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/services/csv_export_service.dart';
import 'package:finta/core/services/csv_import_service.dart';
import 'package:finta/models/transaction_model.dart';

TransactionModel tx({
  required String type,
  required double amount,
  required DateTime date,
  String categoryId = 'cat1',
  String? note,
}) => TransactionModel(
  id: 'tx-${date.millisecondsSinceEpoch}-$amount',
  type: type,
  amount: amount,
  categoryId: categoryId,
  accountId: 'acc1',
  date: date,
  note: note,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  final export = CsvExportService();
  final import = CsvImportService();

  String nameFor(String id) => switch (id) {
    'cat1' => 'Groceries',
    'cat2' => 'Salary',
    _ => 'Unknown',
  };

  group('buildCsv', () {
    test('writes the header the importer auto-detects', () {
      final csv = export.buildCsv(const [], nameFor);

      // Not UI copy: translating this would break column auto-detection for
      // a user re-importing their own export in Indonesian.
      expect(csv.trim(), 'Date,Type,Amount,Category,Note');
      expect(CsvExportService.header, 'Date,Type,Amount,Category,Note');
    });

    test('writes dates as bare ISO days, not full timestamps', () {
      final csv = export.buildCsv([
        tx(type: 'expense', amount: 25000, date: DateTime(2026, 2, 9, 13, 45)),
      ], nameFor);

      expect(csv, contains('2026-02-09,expense,25000.0,Groceries,'));
    });

    test('resolves the category id to its display name', () {
      final csv = export.buildCsv([
        tx(
          type: 'income',
          amount: 8500000,
          date: DateTime(2026, 2, 1),
          categoryId: 'cat2',
        ),
      ], nameFor);

      expect(csv, contains(',Salary,'));
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
        ),
      ];

      final parsed = import.parse(export.buildCsv(transactions, nameFor));
      // The importer's own auto-detection order for our header.
      const mapping = CsvColumnMapping(
        date: 0,
        amount: 2,
        type: 1,
        category: 3,
        note: 4,
      );
      final result = import.mapRows(parsed.dataRows, mapping);

      expect(result.errors, isEmpty);
      expect(result.rows.map((r) => r.date), [
        DateTime(2026, 2, 12),
        DateTime(2026, 2, 1),
      ]);
      expect(result.rows.map((r) => r.amount), [85000, 8500000]);
      expect(result.rows.map((r) => r.type), ['expense', 'income']);
      expect(result.rows.map((r) => r.categoryName), ['Groceries', 'Salary']);
    });

    test('a note containing a comma survives the round trip intact', () {
      // The case unquoted output would silently corrupt: the note would
      // split across columns and shift Category out of position.
      final parsed = import.parse(
        export.buildCsv([
          tx(
            type: 'expense',
            amount: 42000,
            date: DateTime(2026, 2, 12),
            note: 'lunch, coffee',
          ),
        ], nameFor),
      );
      const mapping = CsvColumnMapping(
        date: 0,
        amount: 2,
        type: 1,
        category: 3,
        note: 4,
      );
      final result = import.mapRows(parsed.dataRows, mapping);

      expect(result.errors, isEmpty);
      expect(result.rows.single.note, 'lunch, coffee');
      expect(result.rows.single.categoryName, 'Groceries');
    });
  });
}
