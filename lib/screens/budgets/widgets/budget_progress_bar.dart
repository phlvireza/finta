import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/budget_display.dart';
import '../../../l10n/app_localizations.dart';
import 'budget_pace_bar.dart';

/// Progress bar visualizing budget usage — works for any scope
/// (category/group/overall) and any period length, via
/// [resolveBudgetDisplay] and [AppDateUtils.getCurrentPeriodFor].
class BudgetProgressBar extends StatelessWidget {
  final BudgetStatus status;
  final String symbol;
  final bool useDecimals;
  final int payday;

  const BudgetProgressBar({
    super.key,
    required this.status,
    required this.symbol,
    required this.useDecimals,
    required this.payday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final categories = context.watch<CategoryProvider>();
    final display = resolveBudgetDisplay(
      budget: status.budget,
      categories: categories,
      loc: loc,
      fallbackColor: theme.colorScheme.primary,
    );

    final barColor = AppColors.budgetBarColor(
      isExceeded: status.isExceeded,
      isWarning: status.isWarning,
      categoryColor: display.color,
      isDark: isDark,
    );

    final ratio = status.ratio.clamp(0.0, 1.0);
    final period = AppDateUtils.getCurrentPeriodFor(status.budget.period, payday);
    final timeElapsed = AppDateUtils.periodElapsedFraction(period);
    final pace = budgetPaceFor(status.ratio, timeElapsed);
    final paceLabel = switch (pace) {
      BudgetPace.ahead => loc.paceAhead,
      BudgetPace.onTrack => loc.paceOnTrack,
      BudgetPace.under => loc.paceUnder,
    };

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: display.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(display.icon, size: 16, color: display.color),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Text(display.title, style: theme.textTheme.titleMedium),
              ),
              Text(
                '${NumberUtils.formatPercentage(ratio)} ${loc.used}',
                style: theme.textTheme.labelMedium?.copyWith(color: barColor),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          BudgetPaceBar(
            ratio: ratio,
            timeElapsedFraction: timeElapsed,
            barColor: barColor,
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                paceLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(width: 2),
              InkWell(
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                onTap: () => _showPaceInfo(context, loc),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.info_outline,
                    size: 13,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${NumberUtils.formatCurrency(status.spent, symbol: symbol, useDecimals: useDecimals)} ${loc.spentString}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '${NumberUtils.formatCurrency(status.remaining, symbol: symbol, useDecimals: useDecimals)} ${loc.left}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          if (status.budget.hasRollover && status.rolloverAmount != 0) ...[
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              status.rolloverAmount > 0
                  ? loc.rolledOverPositive(
                      NumberUtils.formatCurrency(status.rolloverAmount, symbol: symbol, useDecimals: useDecimals),
                    )
                  : loc.rolledOverNegative(
                      NumberUtils.formatCurrency(-status.rolloverAmount, symbol: symbol, useDecimals: useDecimals),
                    ),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.textTheme.bodySmall?.color),
            ),
          ],
        ],
      ),
    );
  }

  void _showPaceInfo(BuildContext context, AppLocalizations loc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.paceInfoTitle),
        content: Text(loc.paceExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.gotIt),
          ),
        ],
      ),
    );
  }
}
