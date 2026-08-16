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
}) {
  return CategoryModel(
    id: 'id-$name',
    name: name,
    type: type,
    icon: 'category',
    color: '#8A7E74',
    isDefault: isDefault,
    sortOrder: 0,
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
}
