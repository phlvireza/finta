import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// A budget progress bar with a thin tick marking how far through the
/// period we are. Without it, "85% used" reads identically whether it's
/// day 3 of the period (alarming) or day 27 (fine) — the tick gives the
/// number a time reference. Shared by the budgets list, the budget detail
/// screen and the aggregate donut so all three stay visually consistent.
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
              // A tint of the bar's own colour rather than the neutral
              // surface: the unfilled part then reads as "the rest of this
              // budget" instead of as a separate grey element, and the bar
              // keeps its category identity even at 5% spent.
              backgroundColor: barColor.withValues(alpha: 0.15),
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

/// Localized copy for a [BudgetPace] — shared by every budget row so the
/// wording can't drift between the dashboard, the budgets list, and the
/// budget detail screen.
String budgetPaceLabel(AppLocalizations loc, BudgetPace pace) => switch (pace) {
      BudgetPace.ahead => loc.paceAhead,
      BudgetPace.onTrack => loc.paceOnTrack,
      BudgetPace.under => loc.paceUnder,
    };
