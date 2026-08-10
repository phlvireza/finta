/// Simple moving average over a category's (or overall) totals from the
/// last few periods — the "next period" projection. An empty list has
/// nothing to average, so it projects zero rather than dividing by zero.
double movingAverageProjection(List<double> pastPeriodTotals) {
  if (pastPeriodTotals.isEmpty) return 0;
  return pastPeriodTotals.reduce((a, b) => a + b) / pastPeriodTotals.length;
}
