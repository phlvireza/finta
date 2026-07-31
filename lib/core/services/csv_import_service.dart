import 'package:csv/csv.dart';

/// Which CSV column (by index into a row) feeds each transaction field.
/// -1 means "not present in this file" — [type] falls back to the amount's
/// sign, [category]/[note]/[merchant] are simply left blank.
class CsvColumnMapping {
  final int date;
  final int amount;
  final int type;
  final int category;
  final int note;
  final int merchant;

  const CsvColumnMapping({
    required this.date,
    required this.amount,
    this.type = -1,
    this.category = -1,
    this.note = -1,
    this.merchant = -1,
  });
}

/// A row that failed to parse, with a human-readable reason — collected
/// rather than thrown so one bad line doesn't abort an otherwise-good
/// import (common with hand-edited or bank-exported CSVs).
class CsvImportError {
  final int rowNumber;
  final String reason;
  CsvImportError(this.rowNumber, this.reason);
}

/// One successfully parsed row. [categoryName] is still a name, not an id —
/// resolving it (and auto-creating missing categories) needs the database,
/// which this pure-Dart parser deliberately has no dependency on.
class ParsedImportRow {
  final DateTime date;
  final double amount;
  final String type;
  final String? categoryName;
  final String? note;
  final String? merchant;

  ParsedImportRow({
    required this.date,
    required this.amount,
    required this.type,
    this.categoryName,
    this.note,
    this.merchant,
  });
}

class CsvParseResult {
  final List<String> headers;
  final List<List<dynamic>> dataRows;
  CsvParseResult(this.headers, this.dataRows);
}

/// Parses and maps arbitrary CSV data (Finta's own export, or a bank/other
/// app's export) into transaction rows. Kept free of any database
/// dependency so the parsing/mapping logic — the part actually worth
/// getting right — is unit-testable without one.
class CsvImportService {
  /// Splits raw CSV text into a header row + data rows. Every export this
  /// needs to read (Finta's own, plus typical bank/Mint/YNAB-style exports)
  /// has a header, so callers use it to drive the column-mapping UI.
  CsvParseResult parse(String content) {
    // Normalize line endings first: exports vary between `\r\n` (Windows,
    // most bank exports) and bare `\n` (Unix-authored files) — the
    // converter's `eol` is a single fixed string, so a file (or in-memory
    // string) using the other convention would otherwise fail to split
    // into rows at all.
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(shouldParseNumbers: false, eol: '\n')
        .convert(normalized);
    if (rows.isEmpty) return CsvParseResult(const [], const []);
    final headers = rows.first.map((h) => h.toString().trim()).toList();
    return CsvParseResult(headers, rows.skip(1).toList());
  }

  /// Maps [dataRows] into transactions using [mapping]. Failures are
  /// collected per-row rather than aborting the whole import.
  ({List<ParsedImportRow> rows, List<CsvImportError> errors}) mapRows(
    List<List<dynamic>> dataRows,
    CsvColumnMapping mapping,
  ) {
    final rows = <ParsedImportRow>[];
    final errors = <CsvImportError>[];

    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final rowNumber = i + 1;
      try {
        if (mapping.date < 0 || mapping.date >= row.length) {
          throw const FormatException('missing date column');
        }
        if (mapping.amount < 0 || mapping.amount >= row.length) {
          throw const FormatException('missing amount column');
        }

        final date = _parseDate(row[mapping.date].toString());
        if (date == null) {
          throw FormatException('unrecognized date "${row[mapping.date]}"');
        }

        final rawAmount = row[mapping.amount].toString();
        final signedAmount = _parseAmount(rawAmount);
        if (signedAmount == null) {
          throw FormatException('unrecognized amount "$rawAmount"');
        }

        final type = _parseType(_columnValue(row, mapping.type)) ??
            (signedAmount < 0 ? 'expense' : 'income');

        rows.add(ParsedImportRow(
          date: date,
          amount: signedAmount.abs(),
          type: type,
          categoryName: _nullIfEmpty(_columnValue(row, mapping.category)),
          note: _nullIfEmpty(_columnValue(row, mapping.note)),
          merchant: _nullIfEmpty(_columnValue(row, mapping.merchant)),
        ));
      } catch (e) {
        errors.add(CsvImportError(
          rowNumber,
          e is FormatException ? e.message : e.toString(),
        ));
      }
    }

    return (rows: rows, errors: errors);
  }

  String _columnValue(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].toString().trim();
  }

  String? _nullIfEmpty(String s) => s.isEmpty ? null : s;

  DateTime? _parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // ISO 8601 first — Finta's own export format, and most bank exports.
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    // Common slash/dash-separated formats: try day-first (most of the
    // world) then month-first (US-style exports), keeping whichever
    // produces a valid calendar date.
    final parts = s.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        final year = c < 100 ? 2000 + c : c;
        if (a <= 31 && b <= 12) {
          final d = DateTime(year, b, a);
          if (d.month == b && d.day == a) return d;
        }
        if (b <= 31 && a <= 12) {
          final d = DateTime(year, a, b);
          if (d.month == a && d.day == b) return d;
        }
      }
    }
    return null;
  }

  double? _parseAmount(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    var negative = false;
    if (s.startsWith('(') && s.endsWith(')')) {
      negative = true;
      s = s.substring(1, s.length - 1);
    }
    // Strip currency symbols and thousands separators — keep digits, the
    // decimal point, and a leading minus sign.
    s = s.replaceAll(RegExp(r'[^\d.\-]'), '');
    if (s.isEmpty) return null;
    final value = double.tryParse(s);
    if (value == null) return null;
    return negative ? -value.abs() : value;
  }

  String? _parseType(String raw) {
    final s = raw.toLowerCase();
    if (s.isEmpty) return null;
    if (const ['income', 'credit', 'deposit', 'in'].contains(s)) return 'income';
    if (const ['expense', 'debit', 'withdrawal', 'out'].contains(s)) return 'expense';
    return null;
  }
}
