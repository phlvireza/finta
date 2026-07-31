import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/debt_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/number_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/debt_form.dart';
import 'widgets/repayment_sheet.dart';
import 'widgets/payoff_calculator_dialog.dart';

/// Screen to list, create, log repayments for, and archive debts — split
/// into what's owed to you ("lent") and what you owe ("borrowed"), with a
/// net summary at the top.
class DebtsListScreen extends StatelessWidget {
  const DebtsListScreen({super.key});

  static void showDebtForm(BuildContext context, {DebtModel? debt}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DebtForm(debtToEdit: debt),
    );
  }

  Future<void> _deleteDebt(BuildContext context, DebtModel debt) async {
    final loc = AppLocalizations.of(context)!;
    final provider = context.read<DebtProvider>();
    final usage = await provider.countUsage(debt.id);
    if (!context.mounted) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.deleteDebt,
      message: usage > 0
          ? loc.confirmArchiveDebt(debt.name, usage)
          : loc.confirmDeleteDebt(debt.name),
      confirmText: usage > 0 ? loc.archive : loc.delete,
    );
    if (confirmed) await provider.deleteDebt(debt.id);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<DebtProvider>();
    final debts = provider.activeDebts;

    return Scaffold(
      appBar: AppBar(title: Text(loc.debts)),
      body: debts.isEmpty
          ? EmptyState(
              icon: Icons.handshake_outlined,
              title: loc.noDebtsYet,
              subtitle: loc.noDebtsYetMessage,
              action: ElevatedButton(
                onPressed: () => showDebtForm(context),
                child: Text(loc.addDebt),
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
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        label: loc.owedToYou,
                        amount: provider.totalOwedToMe,
                        color: Colors.green,
                        symbol: settings.currencySymbol,
                        useDecimals: settings.currencyUseDecimals,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingMd),
                    Expanded(
                      child: _SummaryTile(
                        label: loc.youOwe,
                        amount: provider.totalIOwe,
                        color: Colors.redAccent,
                        symbol: settings.currencySymbol,
                        useDecimals: settings.currencyUseDecimals,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXl),
                for (final debt in debts) ...[
                  _DebtCard(
                    debt: debt,
                    onEdit: () => showDebtForm(context, debt: debt),
                    onDelete: () => _deleteDebt(context, debt),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => showDebtForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String symbol;
  final bool useDecimals;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.symbol,
    required this.useDecimals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            NumberUtils.formatCurrency(amount, symbol: symbol, useDecimals: useDecimals),
            style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final DebtModel debt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DebtCard({required this.debt, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<DebtProvider>();
    final outstanding = provider.outstandingOf(debt);
    final settled = provider.isSettled(debt);
    final ratio = debt.principal <= 0 ? 1.0 : (1 - outstanding / debt.principal).clamp(0.0, 1.0);
    final color = debt.isLent ? Colors.green : Colors.redAccent;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: BorderSide(color: theme.colorScheme.outline),
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
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Icon(
                    debt.isLent ? Icons.call_made : Icons.call_received,
                    color: color,
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debt.name, style: theme.textTheme.titleMedium),
                      Text(
                        debt.isLent ? loc.debtTypeLent : loc.debtTypeBorrowed,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                    if (value == 'payoff') PayoffCalculatorDialog.show(context, debt, outstanding);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(loc.edit)),
                    if (debt.isBorrowed && !settled)
                      PopupMenuItem(value: 'payoff', child: Text(loc.payoffCalculator)),
                    PopupMenuItem(value: 'delete', child: Text(loc.delete)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: color,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            if (settled)
              Text(loc.debtSettled, style: theme.textTheme.bodySmall?.copyWith(color: color))
            else
              Text(
                loc.debtOutstandingOfPrincipal(
                  NumberUtils.formatCurrency(outstanding, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
                  NumberUtils.formatCurrency(debt.principal, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
                ),
                style: theme.textTheme.bodySmall,
              ),
            if (debt.dueDate != null && !settled) ...[
              const SizedBox(height: 2),
              Text(
                loc.debtDueDate(AppDateUtils.formatFull(debt.dueDate!)),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (!settled) ...[
              const SizedBox(height: AppConstants.spacingMd),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => RepaymentSheet.show(context, debt),
                  child: Text(loc.logRepaymentAction),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
