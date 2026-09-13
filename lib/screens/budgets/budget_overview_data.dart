import 'dart:math' as math;

import '../../providers/budget_provider.dart';

/// Presentation-only totals for the budgets shown by the selected cadence.
///
/// Every value comes from [BudgetStatus], so rollover and spending semantics
/// stay owned by [BudgetProvider]. This layer only filters and sums them.
class BudgetOverviewTotals {
  final int count;
  final double budgeted;
  final double spent;

  const BudgetOverviewTotals({
    required this.count,
    required this.budgeted,
    required this.spent,
  });

  factory BudgetOverviewTotals.fromStatuses(Iterable<BudgetStatus> statuses) {
    var count = 0;
    var budgeted = 0.0;
    var spent = 0.0;
    for (final status in statuses) {
      count++;
      budgeted += status.effectiveAmount;
      spent += status.spent;
    }
    return BudgetOverviewTotals(count: count, budgeted: budgeted, spent: spent);
  }

  double get difference => budgeted - spent;
  bool get isOverspent => difference < 0;
  double get remaining => math.max(0, difference);
  double get overspent => math.max(0, -difference);
  bool get hasPositiveBudget => budgeted.isFinite && budgeted > 0;

  /// Aggregate usage for presentation, preserving values above 100%.
  ///
  /// A missing ratio is intentionally different from zero usage: rollover
  /// can reduce the effective total to zero or below, where a percentage and
  /// pace marker would imply a meaningful limit that no longer exists.
  double? get usageRatio {
    if (!hasPositiveBudget || !spent.isFinite) return null;
    return math.max(0, spent) / budgeted;
  }
}

List<BudgetStatus> filterBudgetStatusesByCadence(
  Iterable<BudgetStatus> statuses,
  String cadence,
) => statuses.where((status) => status.budget.period == cadence).toList();

/// Returns a stable, rounded upper bound for a zero-based budget chart.
///
/// The result is never derived from ratios or clamped spending, so zero,
/// tiny, overspent, and unusually large values remain proportional.
double budgetChartMaximum(Iterable<BudgetStatus> statuses) {
  var largest = 0.0;
  for (final status in statuses) {
    largest = math.max(largest, math.max(status.effectiveAmount, status.spent));
  }
  if (!largest.isFinite || largest <= 0) return 1;

  final magnitude = math
      .pow(10, (math.log(largest) / math.ln10).floor())
      .toDouble();
  final normalized = largest / magnitude;
  final rounded = switch (normalized) {
    <= 1 => 1.0,
    <= 2 => 2.0,
    <= 5 => 5.0,
    _ => 10.0,
  };
  return rounded * magnitude;
}
