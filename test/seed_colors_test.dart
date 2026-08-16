import 'package:flutter_test/flutter_test.dart';

import 'package:finta/core/constants/app_colors.dart';
import 'package:finta/core/database/seed_data.dart';

void main() {
  group('SeedData.shippedColorFor', () {
    test('resolves an original seed category by type and name', () {
      // Those rows get fresh uuids at install time, so name + type is the
      // only key available — the same one Migrations.seedCategoryRecolours
      // matches on.
      expect(
        SeedData.shippedColorFor(
          id: 'any-uuid',
          type: 'expense',
          name: 'Food & Drinks',
          isDefault: true,
        ),
        '#3F8B4C',
      );
    });

    test('keeps the two "Other" categories apart by type', () {
      // Both lists contain an "Other"; a lookup that ignored type would
      // still pass here today, but only because the two happen to share a
      // hex. Asserted so a future recolour of one can't silently reset the
      // other to the wrong colour.
      expect(
        SeedData.shippedColorFor(
          id: 'any-uuid', type: 'expense', name: 'Other', isDefault: true),
        SeedData.defaultExpenseCategories.last.color,
      );
      expect(
        SeedData.shippedColorFor(
          id: 'any-uuid', type: 'income', name: 'Other', isDefault: true),
        SeedData.defaultIncomeCategories.last.color,
      );
    });

    test('resolves every fixed-id seed by its id', () {
      const cases = {
        SeedData.transferCategoryId: '#8A7E74',
        SeedData.savingsGoalsCategoryId: '#5B8C5A',
        SeedData.debtPaymentsCategoryId: '#C2665A',
        SeedData.debtRepaymentsCategoryId: '#5B8C5A',
        SeedData.donationCategoryId: '#7A8B6F',
      };

      cases.forEach((id, expected) {
        expect(
          SeedData.shippedColorFor(
            // A deliberately wrong name and type: the fixed-id rows must
            // resolve by id alone, since a rename would otherwise strand
            // them.
            id: id,
            type: 'expense',
            name: 'not the seeded name',
            isDefault: true,
          ),
          expected,
          reason: '$id should resolve by id',
        );
      });
    });

    test('returns null for a category the user created', () {
      expect(
        SeedData.shippedColorFor(
          id: 'user-uuid',
          type: 'expense',
          name: 'Motorbike Fuel',
          isDefault: false,
        ),
        isNull,
      );
    });

    test('returns null for a user category that shadows a seed name', () {
      // Nothing stops a user naming their own category "Health". It must
      // not be offered a reset to a colour it never shipped with — which is
      // why isDefault is part of the key.
      expect(
        SeedData.shippedColorFor(
          id: 'user-uuid',
          type: 'expense',
          name: 'Health',
          isDefault: false,
        ),
        isNull,
      );
    });

    test('returns null for a default that has been renamed', () {
      // Documents the known limit of the name lookup, and is the reason the
      // UI does not let a default be renamed in the first place.
      expect(
        SeedData.shippedColorFor(
          id: 'any-uuid',
          type: 'expense',
          name: 'Makanan & Minuman',
          isDefault: true,
        ),
        isNull,
      );
    });
  });

  group('seed colours', () {
    test('every seeded colour is offered by the swatch picker', () {
      // This is what makes "reset to default colour" coherent: the restored
      // hex must be one the strip can render as selected. AppColors carries
      // the same claim in prose; this is the enforcement.
      final seeded = [
        for (final c in SeedData.defaultExpenseCategories) c.color,
        for (final c in SeedData.defaultIncomeCategories) c.color,
        SeedData.shippedColorFor(
          id: SeedData.transferCategoryId, type: 'expense', name: '', isDefault: true)!,
        SeedData.shippedColorFor(
          id: SeedData.savingsGoalsCategoryId, type: 'expense', name: '', isDefault: true)!,
        SeedData.shippedColorFor(
          id: SeedData.debtPaymentsCategoryId, type: 'expense', name: '', isDefault: true)!,
        SeedData.shippedColorFor(
          id: SeedData.debtRepaymentsCategoryId, type: 'income', name: '', isDefault: true)!,
        SeedData.shippedColorFor(
          id: SeedData.donationCategoryId, type: 'expense', name: '', isDefault: true)!,
      ];

      for (final hex in seeded) {
        expect(
          AppColors.swatchOptions,
          contains(hex),
          reason: '$hex is seeded but missing from the swatch picker',
        );
      }
    });

    test('no seeded colour collides with the warning amber', () {
      // A category wearing #D4A05A would be indistinguishable from a budget
      // bar at its "75% spent" threshold. Migration v10 moved the two that
      // did; this keeps them off.
      const warningHex = '#D4A05A';
      expect(AppColors.swatchOptions, isNot(contains(warningHex)));
      for (final c in SeedData.defaultExpenseCategories) {
        expect(c.color, isNot(warningHex));
      }
      for (final c in SeedData.defaultIncomeCategories) {
        expect(c.color, isNot(warningHex));
      }
    });

    test('sort order follows the table order', () {
      // seedCategories uses the list index as sortOrder, so the tables are
      // the display order too — not an incidental detail if one is reordered.
      expect(SeedData.defaultExpenseCategories.first.name, 'Food & Drinks');
      expect(SeedData.defaultExpenseCategories.last.name, 'Other');
      expect(SeedData.defaultIncomeCategories.first.name, 'Salary');
      expect(SeedData.defaultIncomeCategories.last.name, 'Other');
    });
  });
}
