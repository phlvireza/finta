import '../services/csv_import_service.dart';

/// Preview-side helpers for the CSV import flow.
///
/// Kept here rather than in the screen so the "which categories does this
/// import invent?" question is answerable without a widget tree — the import
/// creates categories silently as a side effect of confirming, so the answer
/// is worth asserting in a test.

/// Identity of a category as the importer sees it.
///
/// Type is part of the key, not decoration: the screen matches an existing
/// category on name *and* type, so "Bonus" as income and "Bonus" as expense
/// are two separate categories and an import mentioning both has to create
/// both. Keying on name alone would under-report by one.
String categoryKey(String type, String name) =>
    '$type:${name.trim().toLowerCase()}';

/// The categories [rows] would force the import to create, in the order they
/// first appear in the file.
///
/// [existingKeys] is the caller's already-resolved set of [categoryKey]s for
/// the categories the user has. [fallbackName] is the bucket a row with no
/// category of its own lands in (`loc.importedCategoryName`) — it is counted
/// once for the whole file rather than once per uncategorized row.
List<String> pendingNewCategories({
  required List<ParsedImportRow> rows,
  required Set<String> existingKeys,
  required String fallbackName,
}) {
  final seen = <String>{};
  final pending = <String>[];

  for (final row in rows) {
    // Transfer rows are pinned to the system Transfer category, so an import
    // full of them creates nothing. Counting them here is what made the
    // importer promise — and then create — a duplicate user category called
    // "Transfer" shadowing the system one.
    if (row.isTransfer) continue;
    final name = row.categoryName ?? fallbackName;
    final key = categoryKey(row.type, name);
    if (existingKeys.contains(key)) continue;
    // `seen` and not `pending.contains` — a file with thousands of rows over
    // a handful of categories would otherwise be quadratic.
    if (seen.add(key)) pending.add(name);
  }

  return pending;
}

/// Whether the row's category will have to be created, for the per-row badge
/// in the preview list. Same keying as [pendingNewCategories], so the badge
/// count and the header count cannot disagree.
bool isNewCategory({
  required ParsedImportRow row,
  required Set<String> existingKeys,
  required String fallbackName,
}) =>
    !row.isTransfer &&
    !existingKeys.contains(
      categoryKey(row.type, row.categoryName ?? fallbackName),
    );

/// Identity of an account as the importer sees it: name only, case- and
/// whitespace-insensitive. Unlike a category there is no type to disambiguate
/// on — two wallets cannot share a name.
String accountKey(String name) => name.trim().toLowerCase();

/// The accounts [rows] would force the import to create, in first-seen order.
///
/// Covers both ends of a transfer. [fallbackName] is the account the user
/// picked for rows that name none; it is never reported, because the user
/// chose an account that already exists.
List<String> pendingNewAccounts({
  required List<ParsedImportRow> rows,
  required Set<String> existingKeys,
  required String fallbackName,
}) {
  final seen = <String>{accountKey(fallbackName)};
  final pending = <String>[];

  void consider(String? name) {
    if (name == null) return;
    final key = accountKey(name);
    if (existingKeys.contains(key)) return;
    if (seen.add(key)) pending.add(name.trim());
  }

  for (final row in rows) {
    consider(row.accountName);
    consider(row.toAccountName);
  }

  return pending;
}

/// Transfer rows whose two ends resolve to the same account.
///
/// Only reachable from a hand-edited file — the app's own export cannot
/// produce one — but importing it would write a pair of legs that cancel out
/// on a single account, cluttering the ledger with a move that never happened.
/// `TransactionProvider.addTransfer` rejects the same case with an
/// ArgumentError; here it is collected per row like every other parse failure
/// so one bad line does not abort the import.
List<CsvImportError> transferRowErrors({
  required List<ParsedImportRow> rows,
  required String fallbackName,
}) {
  final errors = <CsvImportError>[];

  for (final row in rows) {
    if (!row.isTransfer) continue;
    final from = accountKey(row.accountName ?? fallbackName);
    final to = accountKey(row.toAccountName!);
    if (from == to) {
      errors.add(
        CsvImportError(
          row.rowNumber,
          'transfer source and destination are the same account',
        ),
      );
    }
  }

  return errors;
}
