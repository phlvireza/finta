import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/database/seed_data.dart';
import 'package:finta/core/utils/default_category_names.dart';

({String id, String name, String type}) row(String id, String name, String type) =>
    (id: id, name: name, type: type);

/// The 14 uuid-id categories exactly as seeded, in English.
List<({String id, String name, String type})> seededEnglish() => [
      for (var i = 0; i < SeedData.defaultExpenseCategoryNames.length; i++)
        row('exp_$i', SeedData.defaultExpenseCategoryNames[i], 'expense'),
      for (var i = 0; i < SeedData.defaultIncomeCategoryNames.length; i++)
        row('inc_$i', SeedData.defaultIncomeCategoryNames[i], 'income'),
    ];

void main() {
  group('resolveDefaultCategoryRenames', () {
    test('renames every seeded default from English to Indonesian', () {
      final renames = resolveDefaultCategoryRenames(
        categories: seededEnglish(),
        languageCode: 'id',
      );
      expect(renames, hasLength(seededEnglish().length));
      expect(renames['exp_0'], 'Makanan & Minuman');
      expect(renames['inc_0'], 'Gaji');
    });

    test('renames back from Indonesian to English', () {
      final indonesian = [
        row('exp_0', 'Makanan & Minuman', 'expense'),
        row('inc_0', 'Gaji', 'income'),
      ];
      final renames = resolveDefaultCategoryRenames(
        categories: indonesian,
        languageCode: 'en',
      );
      expect(renames['exp_0'], 'Food & Drinks');
      expect(renames['inc_0'], 'Salary');
    });

    test('a round trip returns the original names', () {
      final toId = resolveDefaultCategoryRenames(
        categories: seededEnglish(),
        languageCode: 'id',
      );
      final indonesian = [
        for (final c in seededEnglish())
          row(c.id, toId[c.id] ?? c.name, c.type),
      ];
      final backToEn = resolveDefaultCategoryRenames(
        categories: indonesian,
        languageCode: 'en',
      );
      for (final c in seededEnglish()) {
        expect(backToEn[c.id], c.name, reason: 'round trip for ${c.id}');
      }
    });

    // The common case on every launch: nothing to write, so no database
    // transaction and no listener notification.
    test('returns nothing when the names are already correct', () {
      expect(
        resolveDefaultCategoryRenames(categories: seededEnglish(), languageCode: 'en'),
        isEmpty,
      );
    });

    test('is idempotent — a second pass finds nothing left to do', () {
      final first = resolveDefaultCategoryRenames(
        categories: seededEnglish(),
        languageCode: 'id',
      );
      final renamed = [
        for (final c in seededEnglish()) row(c.id, first[c.id] ?? c.name, c.type),
      ];
      expect(
        resolveDefaultCategoryRenames(categories: renamed, languageCode: 'id'),
        isEmpty,
      );
    });

    test('handles an empty category list', () {
      expect(
        resolveDefaultCategoryRenames(categories: const [], languageCode: 'id'),
        isEmpty,
      );
    });

    test('falls back to English for a language it has no names for', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [row('exp_0', 'Makanan & Minuman', 'expense')],
        languageCode: 'fr',
      );
      expect(renames['exp_0'], 'Food & Drinks');
    });
  });

  // 'Other' is seeded once per type, so a name-only match would be ambiguous.
  group('the duplicated Other category', () {
    test('resolves independently for each type', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [
          row('exp_other', 'Other', 'expense'),
          row('inc_other', 'Other', 'income'),
        ],
        languageCode: 'id',
      );
      expect(renames['exp_other'], 'Lainnya');
      expect(renames['inc_other'], 'Lainnya');
    });

    test('does not match an expense name against an income category', () {
      // 'Groceries' is expense-only; the same string on an income row is not
      // a seeded default and must be left alone.
      final renames = resolveDefaultCategoryRenames(
        categories: [row('custom', 'Groceries', 'income')],
        languageCode: 'id',
      );
      expect(renames, isEmpty);
    });
  });

  group('fixed-id categories', () {
    test('are matched by id', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [
          row(SeedData.savingsGoalsCategoryId, 'Savings & Goals', 'expense'),
          row(SeedData.donationCategoryId, 'Donation', 'expense'),
        ],
        languageCode: 'id',
      );
      expect(renames[SeedData.savingsGoalsCategoryId], 'Tabungan & Target');
      expect(renames[SeedData.donationCategoryId], 'Donasi');
    });

    // The id is the stronger signal, so it wins even if the name is something
    // the table has never written.
    test('are matched by id even when the name is unrecognised', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [row(SeedData.donationCategoryId, 'Charity', 'expense')],
        languageCode: 'id',
      );
      expect(renames[SeedData.donationCategoryId], 'Donasi');
    });

    test('the hidden Transfer category is deliberately left alone', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [row(SeedData.transferCategoryId, 'Transfer', 'expense')],
        languageCode: 'id',
      );
      expect(renames, isEmpty);
    });
  });

  group('categories the user owns', () {
    test('a custom category is never renamed', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [
          row('custom_1', 'Kopi', 'expense'),
          row('custom_2', 'Side hustle', 'income'),
        ],
        languageCode: 'id',
      );
      expect(renames, isEmpty);
    });

    test('a custom category is untouched alongside defaults being renamed', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [...seededEnglish(), row('custom_1', 'Kopi', 'expense')],
        languageCode: 'id',
      );
      expect(renames.containsKey('custom_1'), isFalse);
      expect(renames['exp_0'], 'Makanan & Minuman');
    });
  });

  // There is no UNIQUE(name, type) constraint, so a clash would produce two
  // indistinguishable rows in every picker.
  group('name clashes', () {
    test('skips a default whose new name the user already used', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [
          row('exp_0', 'Food & Drinks', 'expense'),
          row('custom_1', 'Makanan & Minuman', 'expense'),
        ],
        languageCode: 'id',
      );
      expect(renames, isEmpty);
    });

    test('compares case-insensitively, as the category form does', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [
          row('exp_0', 'Food & Drinks', 'expense'),
          row('custom_1', 'makanan & minuman', 'expense'),
        ],
        languageCode: 'id',
      );
      expect(renames, isEmpty);
    });

    test('a clash on one row does not block the others', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [
          row('exp_0', 'Food & Drinks', 'expense'),
          row('exp_1', 'Transport', 'expense'),
          row('custom_1', 'Makanan & Minuman', 'expense'),
        ],
        languageCode: 'id',
      );
      expect(renames.containsKey('exp_0'), isFalse);
      expect(renames['exp_1'], 'Transportasi');
    });

    test('a clash confined to one type does not affect the other', () {
      final renames = resolveDefaultCategoryRenames(
        categories: [
          row('inc_0', 'Salary', 'income'),
          row('custom_1', 'Gaji', 'expense'),
        ],
        languageCode: 'id',
      );
      expect(renames['inc_0'], 'Gaji');
    });
  });

  group('the table itself', () {
    test('covers every seeded default name', () {
      for (final name in SeedData.defaultExpenseCategoryNames) {
        expect(
          defaultCategoryNames.any((e) => e.type == 'expense' && e.matchesName(name)),
          isTrue,
          reason: 'no table entry for expense category "$name"',
        );
      }
      for (final name in SeedData.defaultIncomeCategoryNames) {
        expect(
          defaultCategoryNames.any((e) => e.type == 'income' && e.matchesName(name)),
          isTrue,
          reason: 'no table entry for income category "$name"',
        );
      }
    });

    test('gives every entry a name in every supported language', () {
      for (final entry in defaultCategoryNames) {
        for (final code in ['en', 'id']) {
          expect(
            entry.names[code],
            isNotNull,
            reason: 'entry ${entry.names} is missing a "$code" name',
          );
          expect(entry.names[code], isNotEmpty);
        }
      }
    });

    test('keeps names unique within a type and language', () {
      for (final type in ['expense', 'income']) {
        for (final code in ['en', 'id']) {
          final names = defaultCategoryNames
              .where((e) => e.type == type)
              .map((e) => e.names[code]!.toLowerCase())
              .toList();
          expect(
            names.length,
            names.toSet().length,
            reason: 'duplicate $type name in "$code": $names',
          );
        }
      }
    });
  });
}
