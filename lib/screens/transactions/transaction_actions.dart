import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/deletion_operation.dart';
import '../../core/utils/number_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../models/transaction_model.dart';
import '../../providers/ledger_refresh.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';

export '../../core/utils/deletion_operation.dart' show DeletionOutcome;

/// The dialog owns the whole operation, including refresh-only recovery.
/// Capture providers before awaiting so navigation cannot skip the refresh.
Future<DeletionOutcome> confirmDeleteTransaction(
  BuildContext context,
  TransactionModel transaction,
) async {
  final provider = context.read<TransactionProvider>();
  final settings = context.read<SettingsProvider>();
  final loc = AppLocalizations.of(context)!;
  final operation = DeletionOperation(
    delete: () => provider.deleteTransaction(transaction.id),
    refresh: ledgerRefresher(
      context,
      goals: transaction.goalId != null,
      debts: transaction.debtId != null,
    ),
  );
  final amount = NumberUtils.formatCurrency(
    transaction.amount,
    symbol: settings.currencySymbol,
    useDecimals: settings.currencyUseDecimals,
  );
  return await showDialog<DeletionOutcome>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TransactionDeleteDialog(
          operation: operation,
          title: transaction.isTransfer ? loc.deleteTransfer : loc.delete,
          message: transaction.isTransfer
              ? loc.confirmDeleteTransfer
              : loc.confirmDeleteTransactionMessage(
                  transaction.isIncome ? loc.income : loc.expense,
                  amount,
                ),
        ),
      ) ??
      DeletionOutcome.cancelled;
}

class TransactionDeleteDialog extends StatefulWidget {
  final DeletionOperation operation;
  final String title;
  final String message;
  const TransactionDeleteDialog({
    super.key,
    required this.operation,
    required this.title,
    required this.message,
  });

  @override
  State<TransactionDeleteDialog> createState() =>
      _TransactionDeleteDialogState();
}

class _TransactionDeleteDialogState extends State<TransactionDeleteDialog> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await widget.operation.run();
    if (!mounted) return;
    if (widget.operation.refreshed) {
      Navigator.of(context).pop(outcome);
    } else {
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final committed = widget.operation.committed;
    return PopScope(
      canPop: !_busy && !committed,
      child: AlertDialog(
        title: Text(committed ? loc.transactionDeleted : widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              committed
                  ? loc.deletedRefreshFailed
                  : _failed
                  ? loc.errorFailedToDelete
                  : widget.message,
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
        actions: [
          if (!committed)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).pop(
                      _failed
                          ? DeletionOutcome.failed
                          : DeletionOutcome.cancelled,
                    ),
              child: Text(loc.cancel),
            ),
          FilledButton(
            onPressed: _busy ? null : _run,
            style: FilledButton.styleFrom(
              backgroundColor: committed
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
            child: Text(committed ? loc.retry : loc.delete),
          ),
        ],
      ),
    );
  }
}
