import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/goal_projection.dart';

void main() {
  group('projectGoalCompletion', () {
    test('projects a completion date from a steady average contribution', () {
      final result = projectGoalCompletion(
        targetAmount: 6000000,
        currentProgress: 0,
        recentMonthlyContributions: [1000000, 1000000, 1000000],
        referenceDate: DateTime(2026, 1, 15),
      );
      expect(result.monthlyAverage, 1000000);
      // remaining 6,000,000 / avg 1,000,000 = 6 months
      expect(result.date, DateTime(2026, 7, 15));
    });

    test('an already-reached target returns the reference date with zero average', () {
      final result = projectGoalCompletion(
        targetAmount: 1000000,
        currentProgress: 1200000,
        recentMonthlyContributions: [500000],
        referenceDate: DateTime(2026, 1, 15),
      );
      expect(result.date, DateTime(2026, 1, 15));
      expect(result.monthlyAverage, 0);
    });

    test('no contribution history at all returns no projection', () {
      final result = projectGoalCompletion(
        targetAmount: 1000000,
        currentProgress: 0,
        recentMonthlyContributions: [],
      );
      expect(result.date, isNull);
    });

    test('a stalled goal (zero average) returns no projection rather than an infinite date', () {
      final result = projectGoalCompletion(
        targetAmount: 1000000,
        currentProgress: 100000,
        recentMonthlyContributions: [0, 0, 0],
      );
      expect(result.date, isNull);
      expect(result.monthlyAverage, 0);
    });

    test('a negative average (net withdrawals) returns no projection', () {
      final result = projectGoalCompletion(
        targetAmount: 1000000,
        currentProgress: 100000,
        recentMonthlyContributions: [-50000, 0, -20000],
      );
      expect(result.date, isNull);
    });

    test('rounds up a partial month rather than under-projecting', () {
      final result = projectGoalCompletion(
        targetAmount: 1000000,
        currentProgress: 0,
        recentMonthlyContributions: [300000],
        referenceDate: DateTime(2026, 1, 1),
      );
      // 1,000,000 / 300,000 = 3.33 -> rounds up to 4 months
      expect(result.date, DateTime(2026, 5, 1));
    });
  });
}
