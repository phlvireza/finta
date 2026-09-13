/// Where spend-ratio sits relative to how far through the period we are.
enum BudgetPace { ahead, onTrack, under }

BudgetPace budgetPaceFor(double ratio, double timeElapsedFraction) {
  if (timeElapsedFraction <= 0) return BudgetPace.onTrack;
  final pace = ratio / timeElapsedFraction;
  if (pace > 1.15) return BudgetPace.ahead;
  if (pace < 0.85) return BudgetPace.under;
  return BudgetPace.onTrack;
}
