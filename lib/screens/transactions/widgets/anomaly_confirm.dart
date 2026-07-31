import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/confirm_dialog.dart';

/// Confirmation shown when a new expense's amount is a statistical outlier
/// for its category (see [detectAnomaly]) — a "did you mean to spend this
/// much?" nudge, not a hard block. Shared between [AddTransactionScreen]
/// and [QuickAddSheet] so the copy and behavior can't drift between the
/// two entry points.
Future<bool> confirmUnusualAmount(
  BuildContext context, {
  required AppLocalizations loc,
  required String categoryName,
  required String formattedAmount,
  required String formattedTypical,
}) {
  return ConfirmDialog.show(
    context,
    title: loc.unusualAmountTitle,
    message: loc.unusualAmountMessage(formattedAmount, categoryName, formattedTypical),
    confirmText: loc.continueAnyway,
    cancelText: loc.cancel,
  );
}
