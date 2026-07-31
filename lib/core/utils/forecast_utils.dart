/// Projects a period's final expense total by extrapolating the average
/// daily spend seen so far — the same burn-rate math
/// `BurnRateIndicator`'s safe-to-spend figure is built on, run forward
/// instead of divided across the days remaining.
///
/// Returns [spentSoFar] unchanged once the period has ended (nothing left
/// to project) or on day one before any full day has elapsed (too little
/// signal to extrapolate from).
double projectEndOfPeriod({
  required double spentSoFar,
  required DateTime periodStart,
  required DateTime periodEnd,
  DateTime? referenceDate,
}) {
  final today = referenceDate ?? DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  final start = DateTime(periodStart.year, periodStart.month, periodStart.day);
  final end = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);

  if (!todayOnly.isBefore(end)) return spentSoFar;

  final elapsedDays = todayOnly.difference(start).inDays + 1;
  if (elapsedDays <= 0) return spentSoFar;

  final totalDays = end.difference(start).inDays + 1;
  final dailyRate = spentSoFar / elapsedDays;
  return dailyRate * totalDays;
}

/// Simple moving average over a category's (or overall) totals from the
/// last few periods — the "next period" projection. An empty list has
/// nothing to average, so it projects zero rather than dividing by zero.
double movingAverageProjection(List<double> pastPeriodTotals) {
  if (pastPeriodTotals.isEmpty) return 0;
  return pastPeriodTotals.reduce((a, b) => a + b) / pastPeriodTotals.length;
}
