import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/budget_health.dart';
import 'package:finta/models/budget_model.dart';
import 'package:finta/providers/budget_provider.dart';

BudgetStatus status(
  String id,
  double spent, {
  double limit = 100,
  double rollover = 0,
  String period = 'monthly',
}) {
  final date = DateTime(2026, 9, 1);
  return BudgetStatus(
    budget: BudgetModel(
      id: id,
      amount: limit,
      period: period,
      isActive: true,
      createdAt: date,
      updatedAt: date,
    ),
    spent: spent,
    rolloverAmount: rollover,
    period: (
      start: date,
      end: date.add(Duration(days: period == 'weekly' ? 6 : 29)),
    ),
  );
}

void main() {
  test('usage and pace boundaries', () {
    expect(budgetHealthFor(status('a', 74.99), 1), BudgetHealth.withinLimits);
    expect(budgetHealthFor(status('a', 75), 1), BudgetHealth.needsAttention);
    expect(budgetHealthFor(status('a', 100), 1), BudgetHealth.needsAttention);
    expect(budgetHealthFor(status('a', 100.01), 1), BudgetHealth.overLimit);
    expect(budgetHealthFor(status('a', 60), 0.5), BudgetHealth.needsAttention);
    expect(budgetHealthFor(status('a', 57.5), 0.5), BudgetHealth.withinLimits);
    expect(budgetHealthFor(status('a', 20), 0), BudgetHealth.withinLimits);
  });
  test('effective limits include rollover, including exhausted limits', () {
    expect(
      budgetHealthFor(status('a', 100, rollover: 100), 1),
      BudgetHealth.withinLimits,
    );
    expect(
      budgetHealthFor(status('a', 0, rollover: -100), 1),
      BudgetHealth.needsAttention,
    );
    expect(
      budgetHealthFor(status('a', 1, rollover: -100), 1),
      BudgetHealth.overLimit,
    );
    expect(
      budgetHealthFor(status('a', 0, rollover: -110), 1),
      BudgetHealth.overLimit,
    );
  });
  test(
    'rank by severity and usage with stable ties and independent periods',
    () {
      final items = [
        status('healthy', 10),
        status('near', 80),
        status('over', 120),
        status('weekly', 60, period: 'weekly'),
        status('tie', 80),
        status('depleted', 1, limit: 0),
      ];
      final ranked = prioritizeBudgets(
        items,
        (s) => s.budget.period == 'weekly' ? 0.2 : 1,
      );
      expect(ranked.map((s) => s.budget.id), [
        'depleted',
        'over',
        'near',
        'tie',
        'weekly',
        'healthy',
      ]);
      expect(items.first.budget.id, 'healthy');
      expect(prioritizeBudgets([], (_) => 1), isEmpty);
    },
  );
}
