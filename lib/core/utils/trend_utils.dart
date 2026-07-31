/// How far the most recent value in a monthly series sits from the
/// average of the months before it — e.g. "32% above your 6-month
/// average". Pure function so the comparison math is unit-testable
/// without a database.
///
/// Returns null when there's nothing meaningful to compare against: fewer
/// than 2 months of data, or a zero average (comparing against "no
/// spending" produces a meaningless percentage).
({double percent, bool isAbove})? trendVsAverage(List<double> monthlyTotals) {
  if (monthlyTotals.length < 2) return null;
  final latest = monthlyTotals.last;
  final priorMonths = monthlyTotals.sublist(0, monthlyTotals.length - 1);
  final average = priorMonths.reduce((a, b) => a + b) / priorMonths.length;
  if (average <= 0) return null;

  final percent = ((latest - average).abs() / average) * 100;
  return (percent: percent, isAbove: latest > average);
}
