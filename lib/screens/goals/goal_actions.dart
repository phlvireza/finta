import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/goal_provider.dart';
import '../../models/goal_model.dart';
import '../../widgets/confirm_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Confirm, then delete [goal]. Returns true only if it was removed or
/// archived — false when the user cancelled, since that is not a reason for
/// the caller to navigate away.
///
/// A goal with contributions is archived rather than deleted so those
/// transactions keep a resolvable goal name; the dialog says which of the two
/// is about to happen. Shared rather than duplicated per entry point: the
/// goal list deletes from its card menu and the detail screen from an app-bar
/// button, and one action asking two differently-worded questions is how
/// confirmation copy drifts apart.
Future<bool> confirmDeleteGoal(BuildContext context, GoalModel goal) async {
  // Captured before the await — the caller's context may be gone by the time
  // the dialog resolves (deleting from the detail screen pops it).
  final loc = AppLocalizations.of(context)!;
  final provider = context.read<GoalProvider>();

  final usage = await provider.countUsage(goal.id);
  if (!context.mounted) return false;

  final confirmed = await ConfirmDialog.show(
    context,
    title: loc.deleteGoal,
    message: usage > 0
        ? loc.confirmArchiveGoal(goal.name, usage)
        : loc.confirmDeleteGoal(goal.name),
    confirmText: usage > 0 ? loc.archive : loc.delete,
  );
  if (!confirmed) return false;

  await provider.deleteGoal(goal.id);
  return true;
}
