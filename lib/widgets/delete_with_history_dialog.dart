import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// What the user chose when deleting something that has transactions behind
/// it — a goal with contributions, a debt with repayments.
enum DeleteHistoryChoice {
  cancel,

  /// Archive the goal/debt and leave its transactions alone. The default,
  /// because the money really did move and the transactions are the record
  /// of that.
  keepHistory,

  /// Delete the goal/debt *and* its transactions, giving the money back.
  deleteHistory,
}

/// The delete prompt for a goal or debt that still has transactions.
///
/// A plain yes/no confirm can't express this decision. Archiving is right
/// when the contributions were real spending, and wrong when the goal was a
/// mistake — the money never should have left in the first place, and there
/// was previously no way to say so. The user is the only one who knows which
/// case it is, so both outcomes are offered explicitly rather than one being
/// silently chosen for them.
///
/// Returns [DeleteHistoryChoice.cancel] when dismissed by tapping outside,
/// so a dropped dialog can never be read as consent to delete.
class DeleteWithHistoryDialog extends StatelessWidget {
  final String title;
  final String message;
  final String keepLabel;
  final String deleteLabel;
  final String cancelLabel;

  const DeleteWithHistoryDialog({
    super.key,
    required this.title,
    required this.message,
    required this.keepLabel,
    required this.deleteLabel,
    required this.cancelLabel,
  });

  static Future<DeleteHistoryChoice> show(
    BuildContext context, {
    required String title,
    required String message,
    required String keepLabel,
    required String deleteLabel,
    required String cancelLabel,
  }) async {
    final result = await showDialog<DeleteHistoryChoice>(
      context: context,
      builder: (_) => DeleteWithHistoryDialog(
        title: title,
        message: message,
        keepLabel: keepLabel,
        deleteLabel: deleteLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return result ?? DeleteHistoryChoice.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(title),
      content: Text(message, style: theme.textTheme.bodyMedium),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        0,
        AppConstants.spacingLg,
        AppConstants.spacingMd,
      ),
      // Stacked rather than laid out in a row: the two outcomes need enough
      // words to tell them apart, and side by side they truncate to
      // near-identical labels on a phone.
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(DeleteHistoryChoice.keepHistory),
              child: Text(keepLabel),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(DeleteHistoryChoice.deleteHistory),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: Text(deleteLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(DeleteHistoryChoice.cancel),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ],
    );
  }
}
