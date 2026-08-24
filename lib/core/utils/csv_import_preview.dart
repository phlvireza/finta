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
}) => !existingKeys.contains(
  categoryKey(row.type, row.categoryName ?? fallbackName),
);
