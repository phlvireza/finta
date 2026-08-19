import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/health_score.dart';

void main() {
  group('calculateHealthScore savings component', () {
    test('scores zero at or below a zero savings rate', () {
      expect(calculateHealthScore(savingsRate: 0).savingsScore, 0);
      expect(calculateHealthScore(savingsRate: -0.5).savingsScore, 0);
    });

    test('scores 100 at the 20 percent benchmark', () {
      expect(calculateHealthScore(savingsRate: 0.2).savingsScore, 100);
    });

    test('caps at 100 above the benchmark', () {
      expect(calculateHealthScore(savingsRate: 0.9).savingsScore, 100);
    });

    test('scales linearly between zero and the benchmark', () {
      expect(calculateHealthScore(savingsRate: 0.1).savingsScore, 50);
      expect(calculateHealthScore(savingsRate: 0.05).savingsScore, 25);
    });
  });

  group('calculateHealthScore budget component', () {
    // Scored neutrally rather than punitively — a user who has not set up
    // budgets has not done anything wrong.
    test('scores a neutral 70 when there are no active budgets', () {
      expect(calculateHealthScore(savingsRate: 0).budgetScore, 70);
      expect(
        calculateHealthScore(savingsRate: 0, budgetAdherenceRatio: null).budgetScore,
        70,
      );
    });

    test('scores 100 for spending at or under budget', () {
      expect(calculateHealthScore(savingsRate: 0, budgetAdherenceRatio: 0.5).budgetScore, 100);
      expect(calculateHealthScore(savingsRate: 0, budgetAdherenceRatio: 1).budgetScore, 100);
    });

    test('falls one point per percent over budget', () {
      expect(calculateHealthScore(savingsRate: 0, budgetAdherenceRatio: 1.2).budgetScore, 80);
      expect(calculateHealthScore(savingsRate: 0, budgetAdherenceRatio: 1.5).budgetScore, 50);
    });

    test('floors at zero for spending far over budget', () {
      expect(calculateHealthScore(savingsRate: 0, budgetAdherenceRatio: 3).budgetScore, 0);
    });
  });

  group('calculateHealthScore stability component', () {
    test('scores a neutral 70 without enough income history', () {
      expect(calculateHealthScore(savingsRate: 0).stabilityScore, 70);
    });

    test('scores 100 for perfectly steady income', () {
      expect(
        calculateHealthScore(savingsRate: 0, incomeCoefficientOfVariation: 0).stabilityScore,
        100,
      );
    });

    test('falls one point per percent of volatility', () {
      expect(
        calculateHealthScore(savingsRate: 0, incomeCoefficientOfVariation: 0.3).stabilityScore,
        70,
      );
    });

    test('floors at zero for extreme volatility', () {
      expect(
        calculateHealthScore(savingsRate: 0, incomeCoefficientOfVariation: 2).stabilityScore,
        0,
      );
    });
  });

  group('calculateHealthScore composite', () {
    test('weights savings 40 percent and the other two 30 each', () {
      final result = calculateHealthScore(
        savingsRate: 0.2,
        budgetAdherenceRatio: 1,
        incomeCoefficientOfVariation: 0,
      );
      expect(result.overall, 100);
    });

    test('a perfect savings rate alone cannot carry the score', () {
      final result = calculateHealthScore(
        savingsRate: 0.2,
        budgetAdherenceRatio: 3,
        incomeCoefficientOfVariation: 2,
      );
      // 100*0.4 + 0*0.3 + 0*0.3
      expect(result.overall, 40);
    });

    test('the all-neutral case lands mid-range rather than at zero', () {
      final result = calculateHealthScore(savingsRate: 0);
      // 0*0.4 + 70*0.3 + 70*0.3
      expect(result.overall, 42);
    });

    test('reports every sub-score alongside the composite', () {
      final result = calculateHealthScore(
        savingsRate: 0.1,
        budgetAdherenceRatio: 1.2,
        incomeCoefficientOfVariation: 0.3,
      );
      expect(result.savingsScore, 50);
      expect(result.budgetScore, 80);
      expect(result.stabilityScore, 70);
      // 50*0.4 + 80*0.3 + 70*0.3 = 20 + 24 + 21
      expect(result.overall, 65);
    });
  });

  group('coefficientOfVariation', () {
    test('returns null with nothing to vary', () {
      expect(coefficientOfVariation([]), isNull);
      expect(coefficientOfVariation([1000]), isNull);
    });

    test('returns null when the mean is not positive', () {
      expect(coefficientOfVariation([0, 0]), isNull);
      expect(coefficientOfVariation([-100, -200]), isNull);
    });

    test('is zero for identical values', () {
      expect(coefficientOfVariation([1000, 1000, 1000]), 0);
    });

    test('rises as values spread out', () {
      final steady = coefficientOfVariation([900, 1000, 1100])!;
      final erratic = coefficientOfVariation([200, 1000, 1800])!;
      expect(erratic, greaterThan(steady));
    });

    test('is scale independent', () {
      expect(
        coefficientOfVariation([100, 200, 300])!,
        closeTo(coefficientOfVariation([1000, 2000, 3000])!, 1e-12),
      );
    });
  });
}
