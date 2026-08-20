import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/insight_rules.dart';

CategoryComparisonInput input(String id, double current, double previous) =>
    CategoryComparisonInput(categoryId: id, current: current, previous: previous);

void main() {
  group('buildSpendingInsights', () {
    test('returns nothing for no comparisons', () {
      expect(buildSpendingInsights(const []), isEmpty);
    });

    // "Infinitely more than nothing" is not a useful thing to tell someone.
    test('skips a category with no previous spend', () {
      expect(buildSpendingInsights([input('food', 500, 0)]), isEmpty);
      expect(buildSpendingInsights([input('food', 500, -10)]), isEmpty);
    });

    test('ignores movement below the significance threshold', () {
      expect(buildSpendingInsights([input('food', 110, 100)]), isEmpty);
      expect(buildSpendingInsights([input('food', 90, 100)]), isEmpty);
    });

    test('honours a caller-supplied threshold', () {
      expect(buildSpendingInsights([input('food', 110, 100)]), isEmpty);
      expect(
        buildSpendingInsights([input('food', 110, 100)], significantChangeThreshold: 0.05),
        isNotEmpty,
      );
    });

    test('reports the percentage moved, unsigned', () {
      final result = buildSpendingInsights([input('food', 132, 100)]);
      expect(result.first.percent, closeTo(32, 1e-9));

      final drop = buildSpendingInsights([input('rent', 60, 100)]);
      expect(drop.first.kind, InsightKind.decrease);
      expect(drop.first.percent, closeTo(40, 1e-9));
    });

    test('classifies a fall as a decrease', () {
      final result = buildSpendingInsights([input('rent', 50, 100)]);
      expect(result.single.kind, InsightKind.decrease);
    });

    test('promotes the single largest rise to the front', () {
      final result = buildSpendingInsights([
        input('food', 150, 100),
        input('transport', 300, 100),
        input('shopping', 130, 100),
      ]);
      expect(result.first.kind, InsightKind.fastestGrowing);
      expect(result.first.categoryId, 'transport');
    });

    test('does not repeat the promoted category further down', () {
      final result = buildSpendingInsights([
        input('food', 150, 100),
        input('transport', 300, 100),
      ]);
      final transportEntries = result.where((i) => i.categoryId == 'transport');
      expect(transportEntries, hasLength(1));
      expect(transportEntries.single.kind, InsightKind.fastestGrowing);
    });

    test('promotes nothing when every category fell', () {
      final result = buildSpendingInsights([
        input('food', 50, 100),
        input('transport', 40, 100),
      ]);
      expect(result.any((i) => i.kind == InsightKind.fastestGrowing), isFalse);
      expect(result, hasLength(2));
    });

    test('orders the remaining insights by size of movement', () {
      final result = buildSpendingInsights([
        input('a', 130, 100),
        input('b', 50, 100),
        input('c', 200, 100),
      ]);
      // 'c' promoted at 100%; then 'b' at 50%, then 'a' at 30%.
      expect(result.map((i) => i.categoryId).toList(), ['c', 'b', 'a']);
    });

    test('caps the list at maxInsights', () {
      final many = List.generate(10, (i) => input('cat$i', 200.0 + i, 100));
      expect(buildSpendingInsights(many), hasLength(5));
      expect(buildSpendingInsights(many, maxInsights: 3), hasLength(3));
    });

    test('counts the promoted entry against the cap', () {
      final many = List.generate(10, (i) => input('cat$i', 200.0 + i, 100));
      final result = buildSpendingInsights(many, maxInsights: 2);
      expect(result, hasLength(2));
      expect(result.first.kind, InsightKind.fastestGrowing);
    });

    test('treats a change exactly at the threshold as significant', () {
      // 20% is the default threshold and the comparison is a strict less-than.
      expect(buildSpendingInsights([input('food', 120, 100)]), isNotEmpty);
    });
  });
}
