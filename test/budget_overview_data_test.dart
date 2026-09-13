import 'package:flutter_test/flutter_test.dart';
import 'package:finta/models/budget_model.dart';
import 'package:finta/providers/budget_provider.dart';
import 'package:finta/screens/budgets/budget_overview_data.dart';

BudgetStatus status(
  String id, {
  required double budgeted,
  required double spent,
  String cadence = 'monthly',
  double rollover = 0,
}) {
  final start = DateTime(2026, 9, 1);
  return BudgetStatus(
    budget: BudgetModel(
      id: id,
      name: id,
      amount: budgeted,
      period: cadence,
      scope: 'overall',
      isActive: true,
      createdAt: start,
      updatedAt: start,
    ),
    spent: spent,
    rolloverAmount: rollover,
    period: (start: start, end: DateTime(2026, 9, 30)),
  );
}

void main() {
  test('filters status objects without recalculating them', () {
    final monthly = status('monthly', budgeted: 100, spent: 40);
    final weekly = status('weekly', budgeted: 20, spent: 5, cadence: 'weekly');

    expect(filterBudgetStatusesByCadence([monthly, weekly], 'monthly'), [
      monthly,
    ]);
    expect(filterBudgetStatusesByCadence([monthly, weekly], 'weekly'), [
      weekly,
    ]);
  });

  test('totals preserve effective amounts, overlaps, and overspending', () {
    final totals = BudgetOverviewTotals.fromStatuses([
      status('overall', budgeted: 100, spent: 80, rollover: 20),
      status('category', budgeted: 50, spent: 90),
    ]);

    expect(totals.count, 2);
    expect(totals.budgeted, 170);
    expect(totals.spent, 170);
    expect(totals.remaining, 0);
    expect(totals.overspent, 0);

    final over = BudgetOverviewTotals.fromStatuses([
      status('over', budgeted: 100, spent: 120),
    ]);
    expect(over.isOverspent, isTrue);
    expect(over.overspent, 20);
  });

  test('aggregate usage ratio is safe and preserves meaningful precision', () {
    BudgetOverviewTotals totals(
      double budgeted,
      double spent, {
      double rollover = 0,
    }) => BudgetOverviewTotals.fromStatuses([
      status('total', budgeted: budgeted, spent: spent, rollover: rollover),
    ]);

    expect(totals(100, 40).usageRatio, 0.4);
    expect(totals(100, 100).usageRatio, 1);
    expect(totals(100, 150).usageRatio, 1.5);
    expect(totals(100, 60, rollover: 20).usageRatio, 0.5);
    expect(totals(0.01, 0.001).usageRatio, closeTo(0.1, 0.000001));
    expect(totals(1000000000, 750000000).usageRatio, 0.75);
    expect(totals(0, 0).usageRatio, isNull);
    expect(totals(100, 10, rollover: -100).usageRatio, isNull);
    expect(totals(100, 10, rollover: -150).usageRatio, isNull);
  });

  test('chart maximum handles zero, depleted, tiny, and large values', () {
    expect(budgetChartMaximum([]), 1);
    expect(
      budgetChartMaximum([
        status('depleted', budgeted: 100, spent: 0, rollover: -150),
      ]),
      1,
    );
    expect(
      budgetChartMaximum([status('tiny', budgeted: 0.01, spent: 0.001)]),
      0.01,
    );
    expect(
      budgetChartMaximum([
        status('large', budgeted: 1000000000, spent: 1200000000),
      ]),
      2000000000,
    );
  });
}
