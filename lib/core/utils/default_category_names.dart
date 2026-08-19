/// Translations for the seeded default categories, and the rule for deciding
/// which rows a language change should rename.
///
/// The categories are seeded as English rows in the database, not resolved
/// from ARB at render time, because a category name is a user-editable value —
/// for custom categories it is whatever the user typed. Defaults are the
/// exception: no UI can rename them (`manage_categories_screen.dart` renders
/// no edit affordance for `isDefault`, `category_picker.dart` gates the same
/// button, and `deleteCategory` refuses them), so their name is only ever
/// what the app itself wrote, and the app can safely rewrite it.
///
/// Seeding stays English on purpose. `_onCreate` and the migrations both
/// produce the same English rows, so the "a fresh install and a fully upgraded
/// one converge" contract in `DatabaseHelper` is untouched and migrations need
/// no access to a locale. The rename is an ordinary app-layer update that runs
/// once the locale is known.
library;

import '../database/seed_data.dart';

/// One seeded category and its name in every supported language.
class DefaultCategoryName {
  /// Set only for the seeded categories that have a fixed id. The rest are
  /// inserted with fresh uuids, so they can only be matched by type and name.
  final String? id;

  /// 'expense' or 'income'. Required even for id-matched entries, because it
  /// is what disambiguates the two different 'Other' categories.
  final String type;

  /// Language code to name. Every supported language must appear here.
  final Map<String, String> names;

  const DefaultCategoryName({
    this.id,
    required this.type,
    required this.names,
  });

  /// Whether [name] is one this entry has ever been called, in any language.
  bool matchesName(String name) =>
      names.values.any((n) => n.toLowerCase() == name.toLowerCase());
}

const String _fallbackLanguage = 'en';

/// The canonical table. English values come from [SeedData] rather than being
/// repeated here, so the seed and the translation cannot drift apart.
final List<DefaultCategoryName> defaultCategoryNames = [
  // ── Expense, in seeded sortOrder ──────────────────────────
  _expense(0, {'id': 'Makanan & Minuman'}),
  _expense(1, {'id': 'Transportasi'}),
  _expense(2, {'id': 'Belanja'}),
  _expense(3, {'id': 'Tagihan & Utilitas'}),
  _expense(4, {'id': 'Hiburan'}),
  _expense(5, {'id': 'Kesehatan'}),
  _expense(6, {'id': 'Pendidikan'}),
  _expense(7, {'id': 'Kebutuhan Sehari-hari'}),
  _expense(8, {'id': 'Lainnya'}),

  // ── Income, in seeded sortOrder ───────────────────────────
  _income(0, {'id': 'Gaji'}),
  _income(1, {'id': 'Pekerja Lepas'}),
  _income(2, {'id': 'Hadiah'}),
  _income(3, {'id': 'Investasi'}),
  _income(4, {'id': 'Lainnya'}),

  // ── Fixed-id categories, matched by id rather than by name ─
  DefaultCategoryName(
    id: SeedData.savingsGoalsCategoryId,
    type: 'expense',
    names: {'en': SeedData.savingsGoalsCategoryName, 'id': 'Tabungan & Target'},
  ),
  DefaultCategoryName(
    id: SeedData.debtPaymentsCategoryId,
    type: 'expense',
    names: {'en': SeedData.debtPaymentsCategoryName, 'id': 'Pembayaran Utang'},
  ),
  DefaultCategoryName(
    id: SeedData.debtRepaymentsCategoryId,
    type: 'income',
    names: {'en': SeedData.debtRepaymentsCategoryName, 'id': 'Pelunasan Piutang'},
  ),
  DefaultCategoryName(
    id: SeedData.donationCategoryId,
    type: 'expense',
    names: {'en': SeedData.donationCategoryName, 'id': 'Donasi'},
  ),

  // The system 'Transfer' category is deliberately absent: it is excluded
  // from every picker by isSystem, and transaction subtitles already
  // substitute a localized label instead of reading the row's name.
];

DefaultCategoryName _expense(int index, Map<String, String> translations) =>
    DefaultCategoryName(
      type: 'expense',
      names: {
        _fallbackLanguage: SeedData.defaultExpenseCategoryNames[index],
        ...translations,
      },
    );

DefaultCategoryName _income(int index, Map<String, String> translations) =>
    DefaultCategoryName(
      type: 'income',
      names: {
        _fallbackLanguage: SeedData.defaultIncomeCategoryNames[index],
        ...translations,
      },
    );

/// The renames needed to bring the seeded categories into [languageCode],
/// as category id to new name. Only rows that actually need changing appear,
/// so an empty result means there is nothing to write.
///
/// A row is left alone when:
///
/// - nothing in the table matches it — it is user-created, or carries a name
///   no released version ever wrote;
/// - its name is already correct for [languageCode];
/// - renaming it would collide with another category of the same type. There
///   is no `UNIQUE(name, type)` constraint on the table — only a validator in
///   the category form — so renaming onto a name the user already used would
///   silently produce two indistinguishable entries in every picker. Leaving
///   one category in the previous language is the lesser problem.
///
/// Matching considers every language in the table, not just the one the user
/// came from. That is what lets a restored backup heal itself: a database
/// carrying English names while the app runs in Indonesian is recognised and
/// corrected on the next launch.
Map<String, String> resolveDefaultCategoryRenames({
  required List<({String id, String name, String type})> categories,
  required String languageCode,
}) {
  final renames = <String, String>{};

  // Names already in use, per type, lowercased for the same case-insensitive
  // comparison the category form applies. Rebuilt as renames are decided so
  // two defaults cannot both be renamed onto the same free name.
  final taken = <String, Set<String>>{};
  for (final category in categories) {
    taken.putIfAbsent(category.type, () => <String>{}).add(category.name.toLowerCase());
  }

  for (final category in categories) {
    final entry = _entryFor(category);
    if (entry == null) continue;

    final target = entry.names[languageCode] ?? entry.names[_fallbackLanguage];
    if (target == null || target == category.name) continue;

    final typeNames = taken[category.type]!;
    if (typeNames.contains(target.toLowerCase())) continue;

    renames[category.id] = target;
    typeNames.remove(category.name.toLowerCase());
    typeNames.add(target.toLowerCase());
  }

  return renames;
}

/// The table entry describing [category], or null if it is not a seeded
/// default. Fixed-id entries match on id alone; the rest match on type plus a
/// name the entry has carried in some language.
DefaultCategoryName? _entryFor(({String id, String name, String type}) category) {
  for (final entry in defaultCategoryNames) {
    if (entry.id == category.id) return entry;
  }
  for (final entry in defaultCategoryNames) {
    if (entry.id == null &&
        entry.type == category.type &&
        entry.matchesName(category.name)) {
      return entry;
    }
  }
  return null;
}
