import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/squi.dart';
import '../../core/utils/budget_display.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../models/budget_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/error_state.dart';
import '../../widgets/form_sheet.dart';
import '../../widgets/masked_amount.dart';
import '../../widgets/section_card.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/squi/squi_state.dart';
import 'budget_actions.dart';
import 'budget_detail_screen.dart';
import 'budget_overview_data.dart';
import 'widgets/budget_comparison_chart.dart';
import 'widgets/budget_form.dart';
import 'widgets/budget_leftover_card.dart';
import 'widgets/budget_progress_bar.dart';
import 'widgets/budget_summary_card.dart';

/// Screen to list, create, and manage budgets.
class ManageBudgetsScreen extends StatefulWidget {
  /// True when hosted as a tab in the app shell rather than pushed from
  /// More. The shell owns the docked add button in that configuration.
  final bool embedded;

  const ManageBudgetsScreen({super.key, this.embedded = false});

  @override
  State<ManageBudgetsScreen> createState() => _ManageBudgetsScreenState();

  /// Opens the existing create/edit form without changing its persistence
  /// behavior. The app shell calls this for its docked FAB.
  static void showBudgetForm(BuildContext context, {String? budgetId}) {
    FormSheet.show(
      context,
      builder: (_) => BudgetForm(budgetIdToEdit: budgetId),
    );
  }
}

class _ManageBudgetsScreenState extends State<ManageBudgetsScreen> {
  String? _selectedCadence;

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context)!;
    final budgets = budgetProvider.activeBudgets;
    final ended = budgetProvider.endedBudgets;
    final allStatuses = budgets
        .map((budget) => budgetProvider.budgetStatuses[budget.id])
        .whereType<BudgetStatus>()
        .toList();
    final availableCadences = [
      for (final value in const ['weekly', 'monthly'])
        if (budgets.any((budget) => budget.period == value) ||
            ended.any((budget) => budget.period == value))
          value,
    ];
    final defaultCadence = availableCadences.contains('monthly')
        ? 'monthly'
        : 'weekly';
    final cadence = availableCadences.contains(_selectedCadence)
        ? _selectedCadence!
        : defaultCadence;
    final hasCadenceChoice = availableCadences.length > 1;
    final cadenceLabel = cadence == 'weekly' ? loc.weekly : loc.monthly;
    final statuses = filterBudgetStatusesByCadence(allStatuses, cadence);
    final endedForCadence = ended
        .where((budget) => budget.period == cadence)
        .toList();

    Future<void> retry() async {
      try {
        await budgetProvider.loadBudgets(payday: settings.payday);
      } catch (_) {
        // The provider retains the error for the state below to present.
      }
    }

    final fab = widget.embedded
        ? null
        : FloatingActionButton(
            heroTag: null,
            onPressed: () => ManageBudgetsScreen.showBudgetForm(context),
            child: const Icon(Icons.add),
          );

    if (budgetProvider.isLoading && budgets.isEmpty && ended.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.manageBudgets)),
        body: const _BudgetLoadingState(),
        floatingActionButton: fab,
      );
    }

    if (budgetProvider.error != null && budgets.isEmpty && ended.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.manageBudgets)),
        body: ErrorState(title: loc.errorFailedToLoadData, onRetry: retry),
        floatingActionButton: fab,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.manageBudgets)),
      body: budgets.isEmpty && ended.isEmpty
          ? SquiState(
              pose: SquiPose.empty,
              title: loc.squiEmptyBudgets,
              subtitle: loc.squiEmptyBudgetsBody,
              action: FilledButton.icon(
                onPressed: () => ManageBudgetsScreen.showBudgetForm(context),
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
                if (budgetProvider.error != null) ...[
                  _InlineBudgetError(onRetry: retry),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
                if (hasCadenceChoice) ...[
                  Semantics(
                    label: loc.budgetCadenceSelector,
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        key: const ValueKey('budget-cadence-selector'),
                        segments: [
                          for (final value in availableCadences)
                            ButtonSegment(
                              value: value,
                              label: Text(
                                value == 'weekly' ? loc.weekly : loc.monthly,
                              ),
                            ),
                        ],
                        selected: {cadence},
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          minimumSize: WidgetStatePropertyAll(Size(0, 44)),
                        ),
                        onSelectionChanged: (selection) =>
                            setState(() => _selectedCadence = selection.single),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
                if (statuses.isNotEmpty) ...[
                  SectionCard(
                    child: BudgetSummaryCard(
                      statuses: statuses,
                      settings: settings,
                      cadenceLabel: hasCadenceChoice ? null : cadenceLabel,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                  SectionCard(
                    child: BudgetComparisonChart(
                      key: ValueKey('budget-chart-$cadence'),
                      items: [
                        for (final status in statuses)
                          BudgetChartItem(
                            title: resolveBudgetDisplay(
                              budget: status.budget,
                              categories: categories,
                              loc: loc,
                              fallbackColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ).title,
                            status: status,
                          ),
                      ],
                      settings: settings,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                  SectionCard(
                    title: loc.budgetDetailsTitle,
                    child: Column(
                      children: [
                        for (var i = 0; i < statuses.length; i++) ...[
                          if (i > 0)
                            const Divider(height: AppConstants.spacingXl),
                          _ActiveBudgetRow(
                            budget: statuses[i].budget,
                            status: statuses[i],
                            display: resolveBudgetDisplay(
                              budget: statuses[i].budget,
                              categories: categories,
                              loc: loc,
                              fallbackColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            settings: settings,
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  SectionCard(
                    child: _CadenceEmptyState(
                      cadenceLabel: cadenceLabel,
                      onAdd: () => ManageBudgetsScreen.showBudgetForm(context),
                    ),
                  ),
                ],
                // Settlement actions stay visible without displacing the
                // health summary users came here to read.
                if (budgetProvider.pendingLeftovers.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingLg),
                  const BudgetLeftoverCard(),
                ],
                if (endedForCadence.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingLg),
                  SectionCard(
                    title: loc.endedBudgets,
                    child: Column(
                      children: [
                        for (var i = 0; i < endedForCadence.length; i++) ...[
                          if (i > 0)
                            const Divider(height: AppConstants.spacingXl),
                          _EndedBudgetRow(
                            budget: endedForCadence[i],
                            display: resolveBudgetDisplay(
                              budget: endedForCadence[i],
                              categories: categories,
                              loc: loc,
                              fallbackColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                            settings: settings,
                            onDelete: (title) => confirmDeleteBudget(
                              context,
                              budgetId: endedForCadence[i].id,
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
      floatingActionButton: fab,
    );
  }
}

class _BudgetLoadingState extends StatelessWidget {
  const _BudgetLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      children: const [
        SkeletonBox(height: 44),
        SizedBox(height: AppConstants.spacingLg),
        SkeletonBox(height: 176),
        SizedBox(height: AppConstants.spacingLg),
        SkeletonBox(height: 330),
        SizedBox(height: AppConstants.spacingLg),
        SkeletonBox(height: 180),
      ],
    );
  }
}

class _InlineBudgetError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _InlineBudgetError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Material(
      color: theme.colorScheme.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Text(
                loc.budgetStaleDataError,
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(loc.retry)),
          ],
        ),
      ),
    );
  }
}

class _CadenceEmptyState extends StatelessWidget {
  final String cadenceLabel;
  final VoidCallback onAdd;

  const _CadenceEmptyState({required this.cadenceLabel, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SquiState(
      pose: SquiPose.empty,
      title: loc.noBudgetsForCadence(cadenceLabel.toLowerCase()),
      subtitle: loc.noBudgetsForCadenceBody,
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: Text(loc.addBudget),
      ),
    );
  }
}

class _ActiveBudgetRow extends StatelessWidget {
  final BudgetModel budget;
  final BudgetStatus status;
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BudgetDetailScreen(budgetId: budget.id),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: BudgetProgressBar(
            status: status,
            symbol: settings.currencySymbol,
            useDecimals: settings.currencyUseDecimals,
            compact: true,
          ),
        ),
      ),
    );
  }
}

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
    final locale = Localizations.localeOf(context).toString();

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
          minVerticalPadding: AppConstants.spacingMd,
          contentPadding: EdgeInsets.zero,
          leading: Icon(display.icon, color: mutedColor),
          title: Text(display.title),
          subtitle: Text(
            loc.budgetEndedOn(AppDateUtils.formatFull(budget.updatedAt)),
            style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          trailing: MaskedAmount(
            text: NumberUtils.formatCurrencyLocalized(
              budget.amount,
              locale: locale,
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
