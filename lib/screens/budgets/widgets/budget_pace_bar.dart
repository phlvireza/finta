import 'package:flutter/material.dart';

/// A budget progress bar with a thin tick marking how far through the
/// period we are. Without it, "85% used" reads identically whether it's
/// day 3 of the period (alarming) or day 27 (fine) — the tick gives the
/// number a time reference. Shared by BudgetProgressBar (Budgets screen)
/// and BudgetOverview (dashboard) so both stay visually consistent.
class BudgetPaceBar extends StatelessWidget {
  final double ratio;
  final double timeElapsedFraction;
  final Color barColor;
  final double height;

  const BudgetPaceBar({
    super.key,
    required this.ratio,
    required this.timeElapsedFraction,
    required this.barColor,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: height,
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment((timeElapsedFraction.clamp(0.0, 1.0) * 2) - 1, 0),
              child: Container(
                width: 2,
                height: height,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where spend-ratio sits relative to how far through the period we are.
enum BudgetPace { ahead, onTrack, under }

BudgetPace budgetPaceFor(double ratio, double timeElapsedFraction) {
  if (timeElapsedFraction <= 0) return BudgetPace.onTrack;
  final pace = ratio / timeElapsedFraction;
  if (pace > 1.15) return BudgetPace.ahead;
  if (pace < 0.85) return BudgetPace.under;
  return BudgetPace.onTrack;
}
