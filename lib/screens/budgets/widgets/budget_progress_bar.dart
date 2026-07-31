import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/category_model.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';
import 'budget_pace_bar.dart';

/// Progress bar visualizing budget usage.
class BudgetProgressBar extends StatelessWidget {
  final CategoryModel category;
  final BudgetStatus status;
  final String symbol;
  final bool useDecimals;

  const BudgetProgressBar({
    super.key,
    required this.category,
    required this.status,
    required this.symbol,
    required this.useDecimals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    final barColor = AppColors.budgetBarColor(
      isExceeded: status.isExceeded,
      isWarning: status.isWarning,
      categoryColor: category.colorValue,
      isDark: isDark,
    );

    final ratio = status.ratio.clamp(0.0, 1.0);
    final timeElapsed = AppDateUtils.periodElapsedFraction(
      AppDateUtils.getCurrentPeriod(settings.payday),
    );
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
                  color: category.colorValue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(category.iconData, size: 16, color: category.colorValue),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Text(category.name, style: theme.textTheme.titleMedium),
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
