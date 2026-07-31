/// Estimates when a goal will hit its target, extrapolating from recent
/// contribution history. Pure function — no database/provider dependency —
/// so the projection math is unit-testable on its own.
///
/// [recentMonthlyContributions] should be a fixed-length, oldest-first
/// window (e.g. the last 3 calendar months, zero-filled for inactive
/// months — see GoalRepository.getRecentMonthlyContributions) so a goal
/// that's gone quiet correctly projects as "no estimate" rather than
/// averaging over however many months happened to have activity.
({DateTime? date, double monthlyAverage}) projectGoalCompletion({
  required double targetAmount,
  required double currentProgress,
  required List<double> recentMonthlyContributions,
  DateTime? referenceDate,
}) {
  final ref = referenceDate ?? DateTime.now();
  final remaining = targetAmount - currentProgress;
  if (remaining <= 0) return (date: ref, monthlyAverage: 0);
  if (recentMonthlyContributions.isEmpty) return (date: null, monthlyAverage: 0);

  final total = recentMonthlyContributions.reduce((a, b) => a + b);
  final average = total / recentMonthlyContributions.length;
  if (average <= 0) return (date: null, monthlyAverage: average);

  final monthsNeeded = (remaining / average).ceil();
  return (date: DateTime(ref.year, ref.month + monthsNeeded, ref.day), monthlyAverage: average);
}
