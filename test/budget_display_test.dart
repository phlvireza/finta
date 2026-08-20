import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/budget_display.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/models/budget_model.dart';
import 'package:finta/models/category_model.dart';
import 'package:finta/providers/category_provider.dart';
import 'package:finta/repositories/category_repository.dart';

/// Stands in for the real repository so the provider can be populated without
/// a database. Subclassing is how NotificationService is already substituted
/// in recurring_provider_test — no mocking package involved.
class _StubCategoryRepository extends CategoryRepository {
  final List<CategoryModel> _categories;
  _StubCategoryRepository(this._categories);

  @override
  Future<List<CategoryModel>> getAll() async => _categories;
}

final _fixedDate = DateTime(2026, 8, 1);

CategoryModel category(String id, {required String name, String color = '#3F8B4C'}) =>
    CategoryModel(
      id: id,
      name: name,
      type: 'expense',
      icon: 'restaurant',
      color: color,
      isDefault: true,
      sortOrder: 0,
      createdAt: _fixedDate,
    );

BudgetModel budget({
  required String scope,
  String? name,
  List<String> categoryIds = const [],
}) =>
    BudgetModel(
      id: 'budget_1',
      name: name,
      amount: 500000,
      scope: scope,
      categoryIds: categoryIds,
      isActive: true,
      createdAt: _fixedDate,
      updatedAt: _fixedDate,
    );

void main() {
  late AppLocalizations loc;
  late CategoryProvider categories;
  const fallback = Color(0xFFC87941);

  setUp(() async {
    loc = lookupAppLocalizations(const Locale('en'));
    categories = CategoryProvider(
      repository: _StubCategoryRepository([
        category('cat_food', name: 'Food & Drinks', color: '#3F8B4C'),
      ]),
    );
    await categories.loadCategories();
  });

  group('resolveBudgetDisplay for an overall budget', () {
    test('uses the wallet icon and the fallback colour', () {
      final result = resolveBudgetDisplay(
        budget: budget(scope: 'overall'),
        categories: categories,
        loc: loc,
        fallbackColor: fallback,
      );
      expect(result.icon, Icons.account_balance_wallet);
      expect(result.color, fallback);
    });

    test('prefers the user-given name over the generic label', () {
      expect(
        resolveBudgetDisplay(
          budget: budget(scope: 'overall', name: 'Everything'),
          categories: categories,
          loc: loc,
          fallbackColor: fallback,
        ).title,
        'Everything',
      );
    });

    test('falls back to the generic label when unnamed', () {
      expect(
        resolveBudgetDisplay(
          budget: budget(scope: 'overall'),
          categories: categories,
          loc: loc,
          fallbackColor: fallback,
        ).title,
        loc.overallBudget,
      );
    });
  });

  group('resolveBudgetDisplay for a group budget', () {
    test('takes its colour from the first category in the group', () {
      final result = resolveBudgetDisplay(
        budget: budget(scope: 'group', categoryIds: ['cat_food']),
        categories: categories,
        loc: loc,
        fallbackColor: fallback,
      );
      expect(result.icon, Icons.folder_outlined);
      expect(result.color, const Color(0xFF3F8B4C));
    });

    test('falls back when the group is empty', () {
      expect(
        resolveBudgetDisplay(
          budget: budget(scope: 'group'),
          categories: categories,
          loc: loc,
          fallbackColor: fallback,
        ).color,
        fallback,
      );
    });

    test('falls back when the first category no longer exists', () {
      expect(
        resolveBudgetDisplay(
          budget: budget(scope: 'group', categoryIds: ['deleted']),
          categories: categories,
          loc: loc,
          fallbackColor: fallback,
        ).color,
        fallback,
      );
    });

    test('uses the generic group label when unnamed', () {
      expect(
        resolveBudgetDisplay(
          budget: budget(scope: 'group', categoryIds: ['cat_food']),
          categories: categories,
          loc: loc,
          fallbackColor: fallback,
        ).title,
        loc.groupBudget,
      );
    });
  });

  group('resolveBudgetDisplay for a category budget', () {
    test('takes its title, icon and colour from the category', () {
      final result = resolveBudgetDisplay(
        budget: budget(scope: 'category', categoryIds: ['cat_food']),
        categories: categories,
        loc: loc,
        fallbackColor: fallback,
      );
      expect(result.title, 'Food & Drinks');
      expect(result.icon, Icons.restaurant);
    });

    // A budget can outlive the category it points at.
    test('degrades to Unknown when the category is gone', () {
      final result = resolveBudgetDisplay(
        budget: budget(scope: 'category', categoryIds: ['deleted']),
        categories: categories,
        loc: loc,
        fallbackColor: fallback,
      );
      expect(result.title, loc.unknown);
      expect(result.icon, Icons.category);
      expect(result.color, fallback);
    });

    test('ignores the budget name, which belongs to group and overall scopes', () {
      expect(
        resolveBudgetDisplay(
          budget: budget(scope: 'category', name: 'Ignored', categoryIds: ['cat_food']),
          categories: categories,
          loc: loc,
          fallbackColor: fallback,
        ).title,
        'Food & Drinks',
      );
    });

    // Legacy rows predate the scope column, so anything unrecognised must
    // behave like a category budget rather than throwing.
    test('treats an unrecognised scope as a category budget', () {
      expect(
        resolveBudgetDisplay(
          budget: budget(scope: 'legacy', categoryIds: ['cat_food']),
          categories: categories,
          loc: loc,
          fallbackColor: fallback,
        ).title,
        'Food & Drinks',
      );
    });
  });
}
