import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/goal_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/number_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/masked_amount.dart';
import '../../l10n/app_localizations.dart';
import 'goal_actions.dart';
import 'goal_detail_screen.dart';
import 'widgets/goal_form.dart';
import 'widgets/contribute_to_goal_sheet.dart';
import 'widgets/goal_progress_summary.dart';

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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final provider = context.watch<GoalProvider>();
    final goals = provider.activeGoals;
    final archived = provider.archivedGoals;

    return Scaffold(
      appBar: AppBar(title: Text(loc.goals)),
      // The empty state only applies when there is genuinely nothing here.
      // Archived goals alone used to fall into it, hiding the very goals the
      // delete flow promised were kept.
      body: goals.isEmpty && archived.isEmpty
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
                    onDelete: () => confirmDeleteGoal(context, goal),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                ],
                if (archived.isNotEmpty) _ArchivedGoals(goals: archived),
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

/// Goals that were archived instead of deleted, kept collapsed below the
/// active ones.
///
/// This section is the other half of the delete flow's promise. Archiving was
/// already the behavior for a goal with contributions, but with nothing
/// listing archived goals the result was indistinguishable from a delete that
/// had failed to give the money back — the goal was gone, the spending
/// wasn't, and there was nothing left to point at.
class _ArchivedGoals extends StatelessWidget {
  final List<GoalModel> goals;

  const _ArchivedGoals({required this.goals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final provider = context.watch<GoalProvider>();
    final settings = context.watch<SettingsProvider>();

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingLg),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(loc.archivedCount(goals.length), style: theme.textTheme.titleSmall),
          children: [
            for (final goal in goals)
              ListTile(
                title: Text(goal.name),
                subtitle: MaskedAmount(
                  text: NumberUtils.formatCurrency(
                    provider.progressOf(goal.id),
                    symbol: settings.currencySymbol,
                    useDecimals: settings.currencyUseDecimals,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restore') provider.unarchiveGoal(goal.id);
                    if (value == 'purge') confirmPurgeGoal(context, goal);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'restore', child: Text(loc.restore)),
                    PopupMenuItem(value: 'purge', child: Text(loc.deletePermanently)),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goal.id)),
                ),
              ),
          ],
        ),
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
    final provider = context.watch<GoalProvider>();
    final isComplete = provider.progressOf(goal.id) >= goal.targetAmount;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      // Tapping the card means "look inside" — the contributions behind the
      // bar — with edit one tap further in, the same gesture the budget list
      // uses. The menu button and the Contribute button both absorb their own
      // taps, so neither falls through to here.
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goal.id)),
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
              GoalProgressSummary(goal: goal),
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
      ),
    );
  }
}
