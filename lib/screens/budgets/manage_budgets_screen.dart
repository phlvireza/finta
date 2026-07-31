import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/number_utils.dart';
import '../../core/utils/budget_display.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirm_dialog.dart';
import 'widgets/budget_form.dart';
import 'widgets/budget_progress_bar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../l10n/app_localizations.dart';

/// Screen to list, create, and manage budgets.
class ManageBudgetsScreen extends StatelessWidget {
  const ManageBudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgetProvider = context.watch<BudgetProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();

    final budgets = budgetProvider.activeBudgets;

    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.manageBudgets),
      ),
      body: budgets.isEmpty
          ? EmptyState(
              icon: Icons.track_changes,
              title: loc.noBudgetsYet,
              subtitle: loc.setMonthlyLimits,
              action: FilledButton.icon(
                onPressed: () => _showBudgetForm(context),
                icon: const Icon(Icons.add),
                label: Text(loc.createFirstBudget),
              ),
            )
          // A single scrolling list with the chart as its first item — on
          // a small screen the chart scrolls away with the rest of the
          // content instead of permanently squeezing the budget list into
          // whatever space is left under a pinned chart.
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: AppConstants.fabClearance),
              itemCount: budgets.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _BudgetChart(budgetProvider: budgetProvider, settings: settings);
                }
                final budget = budgets[index - 1];
                final status = budgetProvider.budgetStatuses[budget.id];
                final display = resolveBudgetDisplay(
                  budget: budget,
                  categories: categories,
                  loc: loc,
                  fallbackColor: theme.colorScheme.primary,
                );

                if (status == null) {
                  return const SizedBox.shrink();
                }

                return Slidable(
                  key: ValueKey(budget.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.25,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _deleteBudget(context, budget.id, display.title),
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        icon: Icons.delete,
                        label: loc.delete,
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => _showBudgetForm(context, budgetId: budget.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingLg,
                        vertical: AppConstants.spacingMd,
                      ),
                      child: BudgetProgressBar(
                        status: status,
                        symbol: settings.currencySymbol,
                        useDecimals: settings.currencyUseDecimals,
                        payday: settings.payday,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _showBudgetForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showBudgetForm(BuildContext context, {String? budgetId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BudgetForm(budgetIdToEdit: budgetId),
      ),
    );
  }

  Future<void> _deleteBudget(BuildContext context, String id, String categoryName) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.deleteBudget,
      message: loc.removeBudgetFor(categoryName),
      confirmText: loc.delete,
    );

    if (confirmed && context.mounted) {
      try {
        await context.read<BudgetProvider>().deleteBudget(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.errorFailedToDelete)),
          );
        }
      }
    }
  }
}

class _BudgetChart extends StatelessWidget {
  final BudgetProvider budgetProvider;
  final SettingsProvider settings;

  const _BudgetChart({
    required this.budgetProvider,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    double totalBudget = 0;
    double totalSpent = 0;

    for (var b in budgetProvider.activeBudgets) {
      final status = budgetProvider.budgetStatuses[b.id];
      if (status != null) {
        totalBudget += status.effectiveAmount;
        totalSpent += status.spent;
      }
    }

    final isDark = theme.brightness == Brightness.dark;
    final ratio = totalBudget > 0 ? totalSpent / totalBudget : 0.0;
    // Same threshold ladder as every other budget bar in the app — a
    // user at 20% of their aggregate budget should not see a warning
    // colour just because this chart is drawn separately from those.
    final spentColor = AppColors.budgetBarColor(
      isExceeded: ratio >= AppConstants.budgetExceededThreshold,
      isWarning: ratio >= AppConstants.budgetWarningThreshold &&
          ratio < AppConstants.budgetExceededThreshold,
      categoryColor: theme.colorScheme.primary,
      isDark: isDark,
    );
    final remainingColor = theme.colorScheme.surfaceContainerHighest;

    double remaining = totalBudget - totalSpent;
    if (remaining < 0) remaining = 0;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingXl),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 70,
                startDegreeOffset: -90,
                sections: [
                  PieChartSectionData(
                    color: spentColor,
                    value: totalSpent,
                    title: '',
                    radius: 12,
                  ),
                  PieChartSectionData(
                    color: remainingColor,
                    value: remaining,
                    title: '',
                    radius: 12,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.totalSpent,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    NumberUtils.formatCurrency(
                      totalSpent,
                      symbol: settings.currencySymbol,
                      useDecimals: settings.currencyUseDecimals,
                    ),
                    style: AppTypography.amountStyle(
                      color: theme.textTheme.bodyLarge!.color!,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${AppLocalizations.of(context)!.ofString} ${NumberUtils.formatCurrency(totalBudget, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
