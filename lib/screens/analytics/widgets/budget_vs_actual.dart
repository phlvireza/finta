import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';

/// Shows all active budgets and their progress in the analytics tab.
class BudgetVsActual extends StatelessWidget {
  const BudgetVsActual({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgetProvider = context.watch<BudgetProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;

    final statuses = budgetProvider.budgetStatuses.values.toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));

    if (statuses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Budget vs Actual', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.spacingMd),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              children: statuses.map((status) {
                final category = categories.getCategoryById(status.budget.categoryId);
                if (category == null) return const SizedBox.shrink();

                Color barColor;
                if (status.isExceeded) {
                  barColor = isDark ? AppColors.darkExpense : AppColors.lightExpense;
                } else if (status.isWarning) {
                  barColor = AppColors.warning;
                } else {
                  barColor = category.colorValue;
                }

                final ratio = status.ratio.clamp(0.0, 1.0);
                final isLast = status == statuses.last;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : AppConstants.spacingMd),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(category.iconData, size: 16, color: category.colorValue),
                          const SizedBox(width: AppConstants.spacingSm),
                          Expanded(
                            child: Text(category.name, style: theme.textTheme.titleSmall),
                          ),
                          Text(
                            '${NumberUtils.formatCurrency(status.spent, symbol: settings.currencySymbol)} / ${NumberUtils.formatCurrency(status.budget.amount, symbol: settings.currencySymbol)}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.spacingSm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(barColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
