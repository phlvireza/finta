import 'dart:math';

/// A 0-100 financial health score built from three weighted sub-scores.
/// Each sub-score is itself 0-100, so the breakdown can be shown alongside
/// the composite ("your savings rate is strong, but budget adherence is
/// dragging the score down") rather than just a single opaque number.
class HealthScoreBreakdown {
  final int overall;
  final int savingsScore;
  final int budgetScore;
  final int stabilityScore;

  const HealthScoreBreakdown({
    required this.overall,
    required this.savingsScore,
    required this.budgetScore,
    required this.stabilityScore,
  });
}

/// - [savingsRate]: (income - expense) / income for the current period.
///   0% or below scores 0; 20%+ scores 100 (a widely-cited healthy-savings
///   benchmark), linear between.
/// - [budgetAdherenceRatio]: total spent / total budgeted across active
///   budgets. Null when the user has no active budgets — scored neutrally
///   (70) rather than penalized for a feature they haven't set up.
/// - [incomeCoefficientOfVariation]: standard deviation / mean of the last
///   several periods' income — a standard "relative volatility" measure.
///   Null with fewer than two periods of history — also scored neutrally.
///
/// Weighted 40% savings / 30% budget adherence / 30% income stability:
/// savings rate is the most directly actionable of the three, so it
/// dominates the composite.
HealthScoreBreakdown calculateHealthScore({
  required double savingsRate,
  double? budgetAdherenceRatio,
  double? incomeCoefficientOfVariation,
}) {
  final savingsScore = ((savingsRate / 0.2) * 100).clamp(0, 100).round();

  final budgetScore = budgetAdherenceRatio == null
      ? 70
      : (budgetAdherenceRatio <= 1
          ? 100
          : (100 - (budgetAdherenceRatio - 1) * 100).clamp(0, 100).round());

  final stabilityScore = incomeCoefficientOfVariation == null
      ? 70
      : (100 - incomeCoefficientOfVariation * 100).clamp(0, 100).round();

  final overall = (savingsScore * 0.4 + budgetScore * 0.3 + stabilityScore * 0.3).round();

  return HealthScoreBreakdown(
    overall: overall,
    savingsScore: savingsScore,
    budgetScore: budgetScore,
    stabilityScore: stabilityScore,
  );
}

/// Standard deviation / mean of [values] — a scale-independent measure of
/// how much income has bounced around period to period. Null with fewer
/// than two data points (nothing to vary) or a non-positive mean (the
/// ratio would be meaningless).
double? coefficientOfVariation(List<double> values) {
  if (values.length < 2) return null;
  final mean = values.reduce((a, b) => a + b) / values.length;
  if (mean <= 0) return null;
  final variance =
      values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
  return sqrt(variance) / mean;
}
