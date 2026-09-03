import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/debt_provider.dart';
import '../../models/debt_model.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/delete_with_history_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ledger_refresh.dart';

/// Confirm, then delete [debt]. Returns true only if it was removed or
/// archived — false when the user cancelled, since that is not a reason for
/// the caller to navigate away.
///
/// A debt with repayments can't be deleted silently: those repayments are
/// real money movements that already changed an account balance. The user
/// picks between archiving the debt (keeping them) and deleting them too,
/// which is the only honest way to undo a debt created by mistake.
///
/// Shared rather than duplicated per entry point: the debt list deletes from
/// its card menu and the detail screen from an app-bar button, and one action
/// asking two differently-worded questions is how confirmation copy drifts
/// apart.
Future<bool> confirmDeleteDebt(BuildContext context, DebtModel debt) async {
  // Captured before the await — the caller's context may be gone by the time
  // the dialog resolves (deleting from the detail screen pops it).
  final loc = AppLocalizations.of(context)!;
  final provider = context.read<DebtProvider>();

  final usage = await provider.countUsage(debt.id);
  if (!context.mounted) return false;

  if (usage == 0) {
    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.deleteDebt,
      message: loc.confirmDeleteDebt(debt.name),
      confirmText: loc.delete,
    );
    if (!confirmed) return false;
    await provider.deleteDebt(debt.id);
    return true;
  }

  final choice = await DeleteWithHistoryDialog.show(
    context,
    title: loc.deleteDebt,
    message: loc.confirmDeleteDebtWithRepayments(debt.name, usage),
    keepLabel: loc.keepRepayments,
    deleteLabel: loc.deleteRepaymentsToo,
    cancelLabel: loc.cancel,
  );
  if (!context.mounted || choice == DeleteHistoryChoice.cancel) return false;

  if (choice == DeleteHistoryChoice.keepHistory) {
    await provider.deleteDebt(debt.id);
    return true;
  }

  await _purgeDebt(context, provider, debt);
  return true;
}

/// Delete an already-archived debt for good, repayments included.
///
/// Separate from [confirmDeleteDebt] because the choice it offers is already
/// settled: an archived debt *is* the "keep the repayments" outcome, so
/// offering it again would be a no-op dressed up as an option.
Future<bool> confirmPurgeDebt(BuildContext context, DebtModel debt) async {
  final loc = AppLocalizations.of(context)!;
  final provider = context.read<DebtProvider>();

  final usage = await provider.countUsage(debt.id);
  if (!context.mounted) return false;

  final confirmed = await ConfirmDialog.show(
    context,
    title: loc.deletePermanently,
    message: usage > 0
        ? loc.confirmPurgeDebt(debt.name, usage)
        : loc.confirmDeleteDebt(debt.name),
    confirmText: loc.delete,
  );
  if (!confirmed || !context.mounted) return false;

  await _purgeDebt(context, provider, debt);
  return true;
}

/// Delete [debt] with its repayments and refresh everything downstream.
///
/// Deleting the repayments un-moves money, so every derived figure that
/// counted them has to be recomputed — account balances, budget spend,
/// analytics totals. The refresher is built before the delete is awaited so
/// the reload still runs when the screen pops itself on success.
Future<void> _purgeDebt(
  BuildContext context,
  DebtProvider provider,
  DebtModel debt,
) async {
  // allTransactions because the calendar, subscription detection and CSV
  // export all read the unbounded list, and the purged repayments would
  // otherwise linger there.
  final refresh = ledgerRefresher(context, allTransactions: true);

  await provider.deleteDebt(debt.id, deleteRepayments: true);
  await refresh();
}
