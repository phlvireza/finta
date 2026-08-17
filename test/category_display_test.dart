import 'package:flutter_test/flutter_test.dart';

import 'package:finta/core/database/seed_data.dart';
import 'package:finta/core/utils/category_display.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/l10n/app_localizations_en.dart';
import 'package:finta/l10n/app_localizations_id.dart';
import 'package:finta/models/category_model.dart';

CategoryModel _cat(
  String name, {
  String type = 'expense',
  bool isDefault = true,
  bool isSystem = false,
  int sortOrder = 0,
}) {
  return CategoryModel(
    id: 'id-$name',
    name: name,
    type: type,
    icon: 'category',
    color: '#8A7E74',
    isDefault: isDefault,
    isSystem: isSystem,
    sortOrder: sortOrder,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final en = AppLocalizationsEn();
  final id = AppLocalizationsId();

  group('categoryDisplayName', () {
    test('translates a seeded category', () {
      expect(categoryDisplayName(_cat('Food & Drinks'), id), 'Makanan & Minuman');
      expect(categoryDisplayName(_cat('Food & Drinks'), en), 'Food & Drinks');
    });

    test('leaves a user-created category exactly as they typed it', () {
      // Their words, not ours — even when the text happens to look like one
      // of ours, which is what the isDefault check is for.
      final custom = _cat('Kopi Pagi', isDefault: false);
      expect(categoryDisplayName(custom, id), 'Kopi Pagi');
      expect(categoryDisplayName(custom, en), 'Kopi Pagi');
    });

    test('does not translate a custom category that shadows a seed name', () {
      final shadow = _cat('Health', isDefault: false);
      expect(categoryDisplayName(shadow, id), 'Health');
    });

    test('falls back to the stored name for an unrecognised default', () {
      // A default the user somehow renamed: showing their text beats showing
      // a placeholder.
      expect(categoryDisplayName(_cat('Makanan'), id), 'Makanan');
    });
  });

  group('seedCategoryDisplayName', () {
    test('covers every category SeedData seeds, in both locales', () {
      // The guard against adding a seed category later and forgetting the
      // ARB keys — the name would silently render in English forever.
      final seeded = <String>[
        for (final c in SeedData.defaultExpenseCategories) c.name,
        for (final c in SeedData.defaultIncomeCategories) c.name,
        // The fixed-id seeds, whose names live in their seeder methods.
        'Transfer',
        'Savings & Goals',
        'Debt Payments',
        'Debt Repayments',
        'Donation',
      ];

      for (final name in seeded) {
        for (final loc in <AppLocalizations>[en, id]) {
          final translated = seedCategoryDisplayName(name, loc);
          expect(
            translated,
            isNotNull,
            reason: '"$name" is seeded but has no ${loc.localeName} translation',
          );
          expect(translated, isNotEmpty);
        }
      }
    });

    test('English translations round-trip to the stored names', () {
      // The stored name IS the English display name. If these ever diverge,
      // an English user would see one string while CSV export wrote another.
      for (final c in SeedData.defaultExpenseCategories) {
        expect(seedCategoryDisplayName(c.name, en), c.name);
      }
      for (final c in SeedData.defaultIncomeCategories) {
        expect(seedCategoryDisplayName(c.name, en), c.name);
      }
    });

    test('every Indonesian translation actually differs from English', () {
      // Except the loanwords the language really does share with English,
      // which are listed so that adding a new one is a deliberate act rather
      // than an untranslated string slipping through.
      const sharedWithEnglish = {'Freelance', 'Transfer'};

      for (final c in SeedData.defaultExpenseCategories) {
        if (sharedWithEnglish.contains(c.name)) continue;
        expect(
          seedCategoryDisplayName(c.name, id),
          isNot(c.name),
          reason: '"${c.name}" looks untranslated',
        );
      }
    });

    test('returns null for a name the app never seeded', () {
      expect(seedCategoryDisplayName('Kopi Pagi', id), isNull);
      expect(seedCategoryDisplayName('', en), isNull);
    });
  });

  group('findCategoryByAnyName', () {
    // Categories arrive in sortOrder order, so the seeded defaults come
    // first — which is exactly what makes the precedence below load-bearing.
    final shopping = _cat('Shopping', sortOrder: 2);
    final ownBelanja = _cat('Belanja', isDefault: false, sortOrder: 40);

    test('an exact stored-name match beats an earlier displayed-name match', () {
      // The regression this function was extracted for: in Indonesian the
      // seeded "Shopping" displays as "Belanja" and sorts first, so a single
      // loop checking both names per category filed these rows under
      // Shopping instead of the user's own identically-named category.
      final match = findCategoryByAnyName(
        categories: [shopping, ownBelanja],
        name: 'Belanja',
        type: 'expense',
        loc: id,
      );
      expect(match, same(ownBelanja));
    });

    test('falls back to the displayed name when no stored name matches', () {
      final match = findCategoryByAnyName(
        categories: [shopping],
        name: 'Belanja',
        type: 'expense',
        loc: id,
      );
      expect(match, same(shopping));
    });

    test('matches the stored name for a round-trip of our own export', () {
      // The export writes stored names, so this is the common path.
      final match = findCategoryByAnyName(
        categories: [shopping, ownBelanja],
        name: 'Shopping',
        type: 'expense',
        loc: id,
      );
      expect(match, same(shopping));
    });

    test('is case insensitive on both names', () {
      expect(
        findCategoryByAnyName(
          categories: [shopping], name: 'sHoPPing', type: 'expense', loc: id),
        same(shopping),
      );
      expect(
        findCategoryByAnyName(
          categories: [shopping], name: 'belanja', type: 'expense', loc: id),
        same(shopping),
      );
    });

    test('never matches across transaction types', () {
      final salary = _cat('Salary', type: 'income');
      expect(
        findCategoryByAnyName(
          categories: [salary], name: 'Salary', type: 'expense', loc: en),
        isNull,
      );
    });

    test('never matches a system category', () {
      // The Transfer category backs both legs of every transfer; an import
      // must not be able to file rows into it by name.
      final transfer = _cat('Transfer', isSystem: true, sortOrder: -1);
      expect(
        findCategoryByAnyName(
          categories: [transfer], name: 'Transfer', type: 'expense', loc: en),
        isNull,
      );
    });

    test('returns null when nothing matches, so the caller creates one', () {
      expect(
        findCategoryByAnyName(
          categories: [shopping], name: 'Kopi Pagi', type: 'expense', loc: id),
        isNull,
      );
      expect(
        findCategoryByAnyName(
          categories: const [], name: 'Shopping', type: 'expense', loc: en),
        isNull,
      );
    });
  });
}
