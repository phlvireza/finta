import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/goal_provider.dart';
import '../../models/goal_model.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/empty_state.dart';
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
                    onDelete: () => confirmDeleteGoal(context, goal),
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
