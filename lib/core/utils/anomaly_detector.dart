import 'dart:math';

/// Flags whether [amount] is unusually large for a category, given
/// [history] — that category's recent individual transaction amounts
/// (not including [amount] itself). Pure statistics, no database access,
/// so the threshold math is unit-testable on its own.
///
/// Uses a z-score against the sample mean/standard deviation of [history].
/// Only flags amounts *above* the mean — an unusually small purchase isn't
/// something a "did you mean to spend this much?" nudge is for. Requires
/// at least [minHistory] prior transactions; with fewer, there's not
/// enough signal to call anything "unusual" yet.
({bool isAnomaly, double zScore, double mean})? detectAnomaly(
  double amount,
  List<double> history, {
  int minHistory = 5,
  double zThreshold = 2.5,
}) {
  if (history.length < minHistory) return null;

  final mean = history.reduce((a, b) => a + b) / history.length;
  final variance =
      history.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / history.length;
  final stdDev = variance <= 0 ? 0.0 : sqrt(variance);

  if (stdDev == 0) {
    // Every prior transaction was identical — anything different at all
    // is worth flagging if it's meaningfully larger, since z-score is
    // undefined (division by zero) in this case.
    return (isAnomaly: amount > mean * 1.5 && amount > mean, zScore: double.infinity, mean: mean);
  }

  final z = (amount - mean) / stdDev;
  return (isAnomaly: z > zThreshold && amount > mean, zScore: z, mean: mean);
}
