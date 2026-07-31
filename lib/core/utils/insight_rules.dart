enum InsightKind { increase, decrease, fastestGrowing }

/// One category's current vs. previous period spend — the raw input the
/// insight rules compare.
class CategoryComparisonInput {
  final String categoryId;
  final double current;
  final double previous;

  const CategoryComparisonInput({
    required this.categoryId,
    required this.current,
    required this.previous,
  });
}

/// A single rule-based insight — still just data at this point ("Food
/// increased 32%"), not a rendered sentence. Turning it into copy like
/// "You spent 32% more on Food than last month" is the UI layer's job,
/// via [AppLocalizations], so this stays localization-agnostic.
class SpendingInsightData {
  final String categoryId;
  final InsightKind kind;
  final double percent;

  const SpendingInsightData({
    required this.categoryId,
    required this.kind,
    required this.percent,
  });
}

/// Compares each category's current period spend against its previous
/// period and surfaces the ones that moved meaningfully. A category with
/// no prior spend is skipped — "infinitely more than $0" isn't a useful
/// insight. The single biggest increase (if any) is promoted to the front
/// as [InsightKind.fastestGrowing] — the one signal worth a user's
/// attention first — and not duplicated further down the list.
List<SpendingInsightData> buildSpendingInsights(
  List<CategoryComparisonInput> comparisons, {
  double significantChangeThreshold = 0.20,
  int maxInsights = 5,
}) {
  final changes = <SpendingInsightData>[];
  for (final c in comparisons) {
    if (c.previous <= 0) continue;
    final change = (c.current - c.previous) / c.previous;
    if (change.abs() < significantChangeThreshold) continue;
    changes.add(SpendingInsightData(
      categoryId: c.categoryId,
      kind: change > 0 ? InsightKind.increase : InsightKind.decrease,
      percent: change.abs() * 100,
    ));
  }
  changes.sort((a, b) => b.percent.compareTo(a.percent));

  final increases = changes.where((i) => i.kind == InsightKind.increase).toList();
  final result = <SpendingInsightData>[];
  String? promotedCategoryId;
  if (increases.isNotEmpty) {
    final top = increases.first;
    promotedCategoryId = top.categoryId;
    result.add(SpendingInsightData(
      categoryId: top.categoryId,
      kind: InsightKind.fastestGrowing,
      percent: top.percent,
    ));
  }

  for (final change in changes) {
    if (result.length >= maxInsights) break;
    if (change.categoryId == promotedCategoryId) continue;
    result.add(change);
  }

  return result;
}
