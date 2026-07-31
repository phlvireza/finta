import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/category_rollup.dart';
import 'package:finta/models/category_model.dart';
import 'package:finta/providers/analytics_provider.dart';

CategoryModel _cat(String id, {String? parentId}) {
  return CategoryModel(
    id: id,
    name: id,
    type: 'expense',
    icon: 'category',
    color: '#C87941',
    isDefault: false,
    parentId: parentId,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('rollUpToParents', () {
    test('merges a child\'s total into its parent, summing if the parent also has direct spend', () {
      final categories = {
        'lifestyle': _cat('lifestyle'),
        'entertainment': _cat('entertainment', parentId: 'lifestyle'),
        'shopping': _cat('shopping', parentId: 'lifestyle'),
      };
      final data = [
        const CategoryAnalytics(categoryId: 'lifestyle', total: 100, percentage: 0.2),
        const CategoryAnalytics(categoryId: 'entertainment', total: 200, percentage: 0.4),
        const CategoryAnalytics(categoryId: 'shopping', total: 200, percentage: 0.4),
      ];

      final result = rollUpToParents(data, (id) => categories[id]);

      expect(result, hasLength(1));
      expect(result.first.categoryId, 'lifestyle');
      expect(result.first.total, 500);
      expect(result.first.percentage, 1.0);
    });

    test('a top-level category with no children passes through unchanged', () {
      final categories = {'food': _cat('food')};
      final data = [const CategoryAnalytics(categoryId: 'food', total: 50, percentage: 1.0)];

      final result = rollUpToParents(data, (id) => categories[id]);

      expect(result, hasLength(1));
      expect(result.first.categoryId, 'food');
      expect(result.first.total, 50);
    });

    test('a child whose parent is missing (archived/deleted) keeps its own entry', () {
      final categories = {'orphan': _cat('orphan', parentId: 'gone')};
      final data = [const CategoryAnalytics(categoryId: 'orphan', total: 30, percentage: 1.0)];

      final result = rollUpToParents(data, (id) => categories[id]);

      expect(result, hasLength(1));
      expect(result.first.categoryId, 'orphan');
      expect(result.first.total, 30);
    });

    test('percentages are recomputed relative to the rolled-up total, not the original', () {
      final categories = {
        'parent': _cat('parent'),
        'child': _cat('child', parentId: 'parent'),
        'other': _cat('other'),
      };
      final data = [
        const CategoryAnalytics(categoryId: 'child', total: 75, percentage: 0.75),
        const CategoryAnalytics(categoryId: 'other', total: 25, percentage: 0.25),
      ];

      final result = rollUpToParents(data, (id) => categories[id]);
      final parentEntry = result.firstWhere((r) => r.categoryId == 'parent');

      expect(parentEntry.total, 75);
      expect(parentEntry.percentage, 0.75);
    });
  });
}
