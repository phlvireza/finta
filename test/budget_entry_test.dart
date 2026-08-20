import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/budget_entry.dart';
import 'package:finta/models/budget_model.dart';

/// What the "Add expense" button on a budget's detail screen prefills.
///
/// The rule the whole thing rests on: anything prefilled must come from the
/// budget's own `categoryIds`, because `BudgetProvider._spentFor` matches
/// spending against that list literally. Prefill something outside it and the
/// user records an expense that never shows up in the budget they logged it
/// from.
BudgetModel _budget({
  required String scope,
  List<String> categoryIds = const [],
}) {
  final now = DateTime(2026, 3, 25);
  return BudgetModel(
    id: 'budget-1',
    amount: 2000000,
    scope: scope,
    categoryIds: categoryIds,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const food = 'cat-food';
  const transport = 'cat-transport';
  const dining = 'cat-dining';

  group('resolveBudgetEntryCategory', () {
    test('an overall budget prefills nothing', () {
      // Every expense counts toward it, so there is no category to favour.
      final entry = resolveBudgetEntryCategory(
        budget: _budget(scope: 'overall'),
        selectableCategoryIds: {food, transport},
      );

      expect(entry.categoryId, isNull);
      expect(entry.choices, isEmpty);
    });

    test('a category budget prefills its one category', () {
      final entry = resolveBudgetEntryCategory(
        budget: _budget(scope: 'category', categoryIds: [food]),
        selectableCategoryIds: {food, transport},
      );

      expect(entry.categoryId, food);
      expect(entry.choices, isEmpty);
    });

    test('a group budget with several live categories asks first', () {
      final entry = resolveBudgetEntryCategory(
        budget: _budget(scope: 'group', categoryIds: [food, transport, dining]),
        selectableCategoryIds: {food, transport, dining},
      );

      expect(entry.categoryId, isNull);
      // In the budget's own order, so the sheet lists them the way the budget
      // form stored them.
      expect(entry.choices, [food, transport, dining]);
    });

    test('a group budget collapses to a prefill when only one is still live', () {
      final entry = resolveBudgetEntryCategory(
        budget: _budget(scope: 'group', categoryIds: [food, transport, dining]),
        selectableCategoryIds: {transport},
      );

      expect(entry.categoryId, transport);
      expect(entry.choices, isEmpty);
    });

    test('a budget whose category was archived prefills nothing', () {
      // A budget outlives an archived category. CategoryPicker renders blank
      // for an id it can't resolve, which reads as an unset field with no
      // explanation — better to leave it genuinely unset.
      final entry = resolveBudgetEntryCategory(
        budget: _budget(scope: 'category', categoryIds: [food]),
        selectableCategoryIds: {transport},
      );

      expect(entry.categoryId, isNull);
      expect(entry.choices, isEmpty);
    });

    test('a budget with no categories prefills nothing', () {
      // The same empty-list shape budget_transactions_test.dart pins on the
      // query side, reached here by a malformed non-overall budget.
      final entry = resolveBudgetEntryCategory(
        budget: _budget(scope: 'category'),
        selectableCategoryIds: {food},
      );

      expect(entry.categoryId, isNull);
      expect(entry.choices, isEmpty);
    });

    test('never returns both a prefill and a shortlist', () {
      for (final scope in ['category', 'group', 'overall']) {
        final entry = resolveBudgetEntryCategory(
          budget: _budget(scope: scope, categoryIds: [food, transport]),
          selectableCategoryIds: {food, transport},
        );

        expect(entry.categoryId == null || entry.choices.isEmpty, isTrue,
            reason: 'scope $scope returned both');
      }
    });
  });
}
