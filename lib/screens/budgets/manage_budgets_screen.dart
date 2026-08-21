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
import '../../core/utils/date_utils.dart';
import '../../core/utils/budget_display.dart';
import '../../models/budget_model.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_sheet.dart';
import '../../widgets/masked_amount.dart';
import '../../widgets/section_card.dart';
import 'budget_actions.dart';
import 'budget_detail_screen.dart';
import 'widgets/budget_form.dart';
import 'widgets/budget_leftover_card.dart';
import 'widgets/budget_progress_bar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../l10n/app_localizations.dart';

/// Screen to list, create, and manage budgets.
class ManageBudgetsScreen extends StatelessWidget {
  /// True when hosted as a tab in the app shell rather than pushed from
  /// [MoreScreen]. The shell already docks a FAB over the nav bar, so an
  /// embedded instance moves its add action into the app bar instead of
  /// raising a second FAB on top of it.
  final bool embedded;

  const ManageBudgetsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();

    final budgets = budgetProvider.activeBudgets;
    final ended = budgetProvider.endedBudgets;

    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.manageBudgets),
        actions: embedded
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: loc.newBudget,
                  onPressed: () => _showBudgetForm(context),
                ),
              ]
            : null,
      ),
      body: budgets.isEmpty && ended.isEmpty
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.fabClearance,
              ),
              children: [
                // Above the budgets themselves: it's a question waiting on
                // an answer, and it disappears for good once given.
                if (budgetProvider.pendingLeftovers.isNotEmpty) ...[
                  const BudgetLeftoverCard(),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
                if (budgets.isNotEmpty) ...[
                  SectionCard(
                    child: _BudgetChart(budgetProvider: budgetProvider, settings: settings),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                  SectionCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < budgets.length; i++) ...[
                          if (i > 0) const Divider(height: AppConstants.spacingXl),
                          _ActiveBudgetRow(
                            budget: budgets[i],
                            status: budgetProvider.budgetStatuses[budgets[i].id],
                            display: resolveBudgetDisplay(
                              budget: budgets[i],
                              categories: categories,
                              loc: loc,
                              fallbackColor: Theme.of(context).colorScheme.primary,
                            ),
                            settings: settings,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (ended.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingLg),
                  SectionCard(
                    title: loc.endedBudgets,
                    child: Column(
                      children: [
                        for (var i = 0; i < ended.length; i++) ...[
                          if (i > 0) const Divider(height: AppConstants.spacingXl),
                          _EndedBudgetRow(
                            budget: ended[i],
                            display: resolveBudgetDisplay(
                              budget: ended[i],
                              categories: categories,
                              loc: loc,
                              fallbackColor: Theme.of(context).colorScheme.primary,
                            ),
                            settings: settings,
                            onDelete: (title) => confirmDeleteBudget(
                              context,
                              budgetId: ended[i].id,
                              title: title,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
      // Embedded, the shell's docked FAB owns this corner — the add action
      // lives in the app bar instead.
      floatingActionButton: embedded
          ? null
          : FloatingActionButton(
              heroTag: null,
              onPressed: () => _showBudgetForm(context),
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showBudgetForm(BuildContext context, {String? budgetId}) {
    // No keyboard padding here — [FormSheet] inside [BudgetForm] owns it.
    // This used to add its own on top, which both doubled the inset and
    // froze it at whatever it was when the sheet opened, since this
    // context never rebuilds as the keyboard animates in.
    FormSheet.show(
      context,
      builder: (_) => BudgetForm(budgetIdToEdit: budgetId),
    );
  }
}

class _ActiveBudgetRow extends StatelessWidget {
  final BudgetModel budget;
  final BudgetStatus? status;
  final ({String title, IconData icon, Color color}) display;
  final SettingsProvider settings;

  const _ActiveBudgetRow({
    required this.budget,
    required this.status,
    required this.display,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    if (status == null) return const SizedBox.shrink();

    return Slidable(
      key: ValueKey(budget.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => confirmDeleteBudget(
              context,
              budgetId: budget.id,
              title: display.title,
            ),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete,
            label: loc.delete,
          ),
        ],
      ),
      child: InkWell(
        // Tap opens the detail rather than the edit form: the question a
        // budget row prompts is "what did I spend it on", and edit is one
        // tap further in from there.
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BudgetDetailScreen(budgetId: budget.id),
          ),
        ),
        child: BudgetProgressBar(
          status: status!,
          symbol: settings.currencySymbol,
          useDecimals: settings.currencyUseDecimals,
          compact: true,
        ),
      ),
    );
  }
}

/// A one-off budget that has run its course. Rendered dimmed rather than
/// dropped from the list: a budget the user set silently disappearing at
/// the period boundary reads as data loss, even though it is exactly what
/// "repeat off" was asked to do. Still swipe-to-delete, so the list can be
/// cleared deliberately.
///
/// No progress bar — an ended budget's status is never computed (only
/// active budgets are, since a stray status for an inactive budget would
/// wrongly make `getStatusForCategory` treat that category as already
/// covered), so there is no spend figure to draw a bar from without
/// fabricating one.
class _EndedBudgetRow extends StatelessWidget {
  final BudgetModel budget;
  final ({String title, IconData icon, Color color}) display;
  final SettingsProvider settings;
  final void Function(String title) onDelete;

  const _EndedBudgetRow({
    required this.budget,
    required this.display,
    required this.settings,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Slidable(
      key: ValueKey('ended-${budget.id}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(display.title),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete,
            label: loc.delete,
          ),
        ],
      ),
      child: Opacity(
        opacity: 0.6,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(display.icon, color: mutedColor),
          title: Text(display.title),
          subtitle: Text(
            loc.budgetEndedOn(AppDateUtils.formatFull(budget.updatedAt)),
            style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          trailing: MaskedAmount(
            text: NumberUtils.formatCurrency(
              budget.amount,
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
          ),
        ),
      ),
    );
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
    final loc = AppLocalizations.of(context)!;

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
      isExceeded: ratio > AppConstants.budgetExceededThreshold,
      isWarning: ratio >= AppConstants.budgetWarningThreshold &&
          ratio < AppConstants.budgetExceededThreshold,
      categoryColor: theme.colorScheme.primary,
      isDark: isDark,
    );
    final remainingColor = theme.colorScheme.surfaceContainerHighest;

    // The chart section can't be negative, but the caption should be: a
    // clamped zero would read as "nothing left" whether the user is exactly
    // on budget or 2M over it.
    final netRemaining = totalBudget - totalSpent;
    final remaining = netRemaining < 0 ? 0.0 : netRemaining;

    return Column(
      children: [
        Stack(
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
              width: 124,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The centre reads "how much can I still spend" first —
                  // "Left this period" plus the remaining amount — rather
                  // than leading with the spent total, which is repeated
                  // (alongside the budgeted total) in the caption below.
                  Text(
                    netRemaining < 0 ? loc.overBudget : loc.leftThisPeriod,
                    style: theme.textTheme.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      NumberUtils.formatCurrency(
                        netRemaining < 0 ? -netRemaining : netRemaining,
                        symbol: settings.currencySymbol,
                        useDecimals: settings.currencyUseDecimals,
                      ),
                      style: AppTypography.amountStyle(
                        color: netRemaining < 0 ? spentColor : theme.textTheme.bodyLarge!.color!,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Text(
          loc.spentOfTotal(
            NumberUtils.formatCurrency(totalSpent, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
            NumberUtils.formatCurrency(totalBudget, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
          ),
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
