import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/budget_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Confirm, then delete [budgetId]. Returns true only if it was deleted —
/// false when the user cancelled *or* the delete failed, since neither is a
/// reason for the caller to navigate away.
///
/// Shared rather than duplicated per entry point: the budget list deletes by
/// swipe and the detail screen by app-bar button, and one action asking two
/// differently-worded questions is how confirmation copy drifts apart.
Future<bool> confirmDeleteBudget(
  BuildContext context, {
  required String budgetId,
  required String title,
}) async {
  // Captured before the await — the caller's context may be gone by the time
  // the dialog resolves (deleting from the detail screen pops it).
  final loc = AppLocalizations.of(context)!;
  final provider = context.read<BudgetProvider>();
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await ConfirmDialog.show(
    context,
    title: loc.deleteBudget,
    message: loc.removeBudgetFor(title),
    confirmText: loc.delete,
  );
  if (!confirmed) return false;

  try {
    await provider.deleteBudget(budgetId);
    return true;
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(loc.errorFailedToDelete)));
    return false;
  }
}
