import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/goal_model.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/delete_with_history_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Confirm, then delete [goal]. Returns true only if it was removed or
/// archived — false when the user cancelled, since that is not a reason for
/// the caller to navigate away.
///
/// A goal with contributions can't be deleted silently: those contributions
/// are real expenses that already moved an account balance. The user picks
/// between archiving the goal (keeping them) and deleting them too, which is
/// the only honest way to undo a goal created by mistake.
///
/// Shared rather than duplicated per entry point: the goal list deletes from
/// its card menu and the detail screen from an app-bar button, and one action
/// asking two differently-worded questions is how confirmation copy drifts
/// apart.
Future<bool> confirmDeleteGoal(BuildContext context, GoalModel goal) async {
  // Captured before the await — the caller's context may be gone by the time
  // the dialog resolves (deleting from the detail screen pops it).
  final loc = AppLocalizations.of(context)!;
  final provider = context.read<GoalProvider>();

  final usage = await provider.countUsage(goal.id);
  if (!context.mounted) return false;

  if (usage == 0) {
    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.deleteGoal,
      message: loc.confirmDeleteGoal(goal.name),
      confirmText: loc.delete,
    );
    if (!confirmed) return false;
    await provider.deleteGoal(goal.id);
    return true;
  }

  final choice = await DeleteWithHistoryDialog.show(
    context,
    title: loc.deleteGoal,
    message: loc.confirmDeleteGoalWithContributions(goal.name, usage),
    keepLabel: loc.keepContributions,
    deleteLabel: loc.deleteContributionsToo,
    cancelLabel: loc.cancel,
  );
  if (!context.mounted || choice == DeleteHistoryChoice.cancel) return false;

  if (choice == DeleteHistoryChoice.keepHistory) {
    await provider.deleteGoal(goal.id);
    return true;
  }

  await _purgeGoal(context, provider, goal);
  return true;
}

/// Delete an already-archived goal for good, contributions included.
///
/// Separate from [confirmDeleteGoal] because the choice it offers is already
/// settled: an archived goal *is* the "keep the contributions" outcome, so
/// offering it again would be a no-op dressed up as an option. What's left is
/// a plain destructive confirm.
Future<bool> confirmPurgeGoal(BuildContext context, GoalModel goal) async {
  final loc = AppLocalizations.of(context)!;
  final provider = context.read<GoalProvider>();

  final usage = await provider.countUsage(goal.id);
  if (!context.mounted) return false;

  final confirmed = await ConfirmDialog.show(
    context,
    title: loc.deletePermanently,
    message: usage > 0
        ? loc.confirmPurgeGoal(goal.name, usage)
        : loc.confirmDeleteGoal(goal.name),
    confirmText: loc.delete,
  );
  if (!confirmed || !context.mounted) return false;

  await _purgeGoal(context, provider, goal);
  return true;
}

/// Delete [goal] with its contributions and refresh everything downstream.
///
/// Deleting the contributions un-spends money, so every derived figure that
/// counted them has to be recomputed — account balances, budget spend,
/// analytics totals. Providers are captured before the first await, and the
/// fan-out mirrors the one ContributeToGoalSheet does on the way in.
Future<void> _purgeGoal(
  BuildContext context,
  GoalProvider provider,
  GoalModel goal,
) async {
  final txProvider = context.read<TransactionProvider>();
  final budgetProvider = context.read<BudgetProvider>();
  final accountProvider = context.read<AccountProvider>();
  final analytics = context.read<AnalyticsProvider>();
  final settings = context.read<SettingsProvider>();

  await provider.deleteGoal(goal.id, deleteContributions: true);
  await txProvider.loadTransactions(payday: settings.payday);
  await txProvider.loadAllTransactions();
  await budgetProvider.loadBudgets(payday: settings.payday);
  await accountProvider.loadAccounts();
  await analytics.loadForCurrentPeriod(settings.payday);
}
