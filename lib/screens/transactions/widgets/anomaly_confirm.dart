import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/insights_provider.dart';
import '../../../providers/settings_provider.dart';
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

/// Runs the outlier check for [categoryId]/[amount] and, if it trips, asks
/// the user whether to go ahead. Returns false only when they back out.
///
/// Both entry points ([AddTransactionScreen] and [QuickAddSheet]) ran a
/// verbatim copy of this — the lookup, the two currency formats and the
/// mounted guards — and the copies had already drifted: one checked
/// `categoryId != null` first while the other went straight to `!`, so the
/// same unset category was a nudge in one form and a crash in the other.
/// The nullable [categoryId] here is that hardened path, kept for both.
///
/// Callers still decide *when* an amount is worth checking (a transfer has
/// no category to compare against; an edit is not a new spend) — that guard
/// differs per form and stays at the call site.
Future<bool> confirmAnomalyIfNeeded(
  BuildContext context, {
  required AppLocalizations loc,
  required String? categoryId,
  required double amount,
}) async {
  if (categoryId == null) return true;

  final check = await context.read<InsightsProvider>().checkAnomaly(
    categoryId,
    amount,
  );
  if (!context.mounted) return false;
  if (check == null || !check.isAnomaly) return true;

  final categoryName =
      context.read<CategoryProvider>().getCategoryById(categoryId)?.name ??
      loc.unknown;
  final settings = context.read<SettingsProvider>();

  String money(double value) => NumberUtils.formatCurrency(
    value,
    symbol: settings.currencySymbol,
    useDecimals: settings.currencyUseDecimals,
  );

  final proceed = await confirmUnusualAmount(
    context,
    loc: loc,
    categoryName: categoryName,
    formattedAmount: money(amount),
    formattedTypical: money(check.mean),
  );
  return proceed && context.mounted;
}
