import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/goal_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';

/// The progress bar, "X of Y", percentage and target/projection line for one
/// goal.
///
/// Shared by the goal card and the goal detail screen so the two can never
/// disagree about a goal's progress — the detail screen exists to show the
/// contributions *behind* the number the card shows, and a second copy of
/// this arithmetic would be the easiest way for those to drift apart.
class GoalProgressSummary extends StatelessWidget {
  final GoalModel goal;

  const GoalProgressSummary({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<GoalProvider>();
    final progress = provider.progressOf(goal.id);
    final ratio = goal.targetAmount <= 0 ? 0.0 : (progress / goal.targetAmount).clamp(0.0, 1.0);
    final isComplete = progress >= goal.targetAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: goal.colorValue,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loc.goalProgressAmount(
                NumberUtils.formatCurrency(progress, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
                NumberUtils.formatCurrency(goal.targetAmount, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
              ),
              style: theme.textTheme.bodySmall,
            ),
            Text(NumberUtils.formatPercentage(ratio), style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 2),
        if (isComplete)
          Text(loc.goalComplete, style: theme.textTheme.bodySmall?.copyWith(color: goal.colorValue))
        else if (goal.targetDate != null)
          Text(
            loc.goalTargetDate(AppDateUtils.formatFull(goal.targetDate!)),
            style: theme.textTheme.bodySmall,
          )
        else
          FutureBuilder<({DateTime? date, double monthlyAverage})>(
            future: provider.getProjection(goal),
            builder: (context, snapshot) {
              final projected = snapshot.data?.date;
              if (projected == null) return const SizedBox.shrink();
              return Text(
                loc.goalProjectedDate(AppDateUtils.formatFull(projected)),
                style: theme.textTheme.bodySmall,
              );
            },
          ),
      ],
    );
  }
}
