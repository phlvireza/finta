import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../budgets/widgets/budget_pace_bar.dart';

/// Budget overview — shows top budget progress bars on the dashboard.
class BudgetOverview extends StatelessWidget {
  const BudgetOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgetProvider = context.watch<BudgetProvider>();
    final topStatuses = budgetProvider.getTopStatuses(AppConstants.budgetOverviewCount);

    if (topStatuses.isEmpty) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.budgets, style: theme.textTheme.titleLarge),
            const SizedBox(width: 2),
            InkWell(
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              onTap: () => _showPaceInfo(context, loc),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingXs),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMd),
        ...topStatuses.map((status) => _BudgetItem(status: status)),
      ],
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

class _BudgetItem extends StatelessWidget {
  final BudgetStatus status;

  const _BudgetItem({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final category = categories.getCategoryById(status.budget.categoryId);

    if (category == null) return const SizedBox.shrink();

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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(category.iconData, size: 18, color: category.colorValue),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: Text(
                    category.name,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberUtils.formatCurrency(status.spent, symbol: settings.currencySymbol)} / ${NumberUtils.formatCurrency(status.budget.amount, symbol: settings.currencySymbol)}',
                      style: theme.textTheme.labelSmall,
                    ),
                    if (status.isExceeded)
                      Text(
                        AppLocalizations.of(context)!.overBudget,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: barColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            BudgetPaceBar(
              ratio: ratio,
              timeElapsedFraction: timeElapsed,
              barColor: barColor,
              height: 6,
            ),
          ],
        ),
      ),
    );
  }
}
