import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/goal_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/number_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/goal_form.dart';
import 'widgets/contribute_to_goal_sheet.dart';

/// Screen to list, create, contribute to, and archive savings goals.
class GoalsListScreen extends StatelessWidget {
  const GoalsListScreen({super.key});

  static void showGoalForm(BuildContext context, {GoalModel? goal}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GoalForm(goalToEdit: goal),
    );
  }

  Future<void> _deleteGoal(BuildContext context, GoalModel goal) async {
    final loc = AppLocalizations.of(context)!;
    final provider = context.read<GoalProvider>();
    final usage = await provider.countUsage(goal.id);
    if (!context.mounted) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.deleteGoal,
      message: usage > 0
          ? loc.confirmArchiveGoal(goal.name, usage)
          : loc.confirmDeleteGoal(goal.name),
      confirmText: usage > 0 ? loc.archive : loc.delete,
    );
    if (confirmed) await provider.deleteGoal(goal.id);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final provider = context.watch<GoalProvider>();
    final goals = provider.activeGoals;

    return Scaffold(
      appBar: AppBar(title: Text(loc.goals)),
      body: goals.isEmpty
          ? EmptyState(
              icon: Icons.savings_outlined,
              title: loc.noGoalsYet,
              subtitle: loc.noGoalsYetMessage,
              action: ElevatedButton(
                onPressed: () => showGoalForm(context),
                child: Text(loc.addGoal),
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
                for (final goal in goals) ...[
                  _GoalCard(
                    goal: goal,
                    onEdit: () => showGoalForm(context, goal: goal),
                    onDelete: () => _deleteGoal(context, goal),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => showGoalForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({required this.goal, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<GoalProvider>();
    final progress = provider.progressOf(goal.id);
    final ratio = goal.targetAmount <= 0 ? 0.0 : (progress / goal.targetAmount).clamp(0.0, 1.0);
    final isComplete = progress >= goal.targetAmount;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: goal.colorValue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Icon(Icons.savings_outlined, color: goal.colorValue),
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: Text(goal.name, style: theme.textTheme.titleMedium),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(loc.edit)),
                    PopupMenuItem(value: 'delete', child: Text(loc.delete)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
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
            if (!isComplete) ...[
              const SizedBox(height: AppConstants.spacingMd),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => ContributeToGoalSheet.show(context, goal),
                  child: Text(loc.contribute),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
