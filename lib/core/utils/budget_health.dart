import 'budget_pace.dart';
import '../../providers/budget_provider.dart';
import '../constants/app_constants.dart';

enum BudgetHealth { overLimit, needsAttention, withinLimits }

BudgetHealth budgetHealthFor(BudgetStatus status, double elapsed) {
  if (status.spent > status.effectiveAmount) return BudgetHealth.overLimit;
  if (status.effectiveAmount <= 0) return BudgetHealth.needsAttention;
  if (status.ratio >= AppConstants.budgetWarningThreshold ||
      (budgetPaceFor(status.ratio, elapsed) == BudgetPace.ahead)) {
    return BudgetHealth.needsAttention;
  }
  return BudgetHealth.withinLimits;
}

/// Preserve input order for equal severity/usage, independently of sort stability.
List<BudgetStatus> prioritizeBudgets(
  List<BudgetStatus> statuses,
  double Function(BudgetStatus) elapsedFor,
) {
  final indexed = statuses.indexed.toList();
  double priority(BudgetStatus s) => s.effectiveAmount > 0
      ? s.ratio
      : s.spent > s.effectiveAmount
      ? double.infinity
      : 0;
  indexed.sort((a, b) {
    final health = budgetHealthFor(
      a.$2,
      elapsedFor(a.$2),
    ).index.compareTo(budgetHealthFor(b.$2, elapsedFor(b.$2)).index);
    if (health != 0) return health;
    final usage = priority(b.$2).compareTo(priority(a.$2));
    return usage != 0 ? usage : a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList();
}
