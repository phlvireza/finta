import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/debt_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/number_utils.dart';
import '../../widgets/squi/squi_state.dart';
import '../../core/constants/squi.dart';
import '../../widgets/masked_amount.dart';
import '../../widgets/section_card.dart';
import '../../widgets/tinted_icon.dart';
import '../../l10n/app_localizations.dart';
import 'debt_actions.dart';
import 'debt_detail_screen.dart';
import 'widgets/debt_form.dart';
import 'widgets/debt_progress_summary.dart';
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<DebtProvider>();
    final debts = provider.activeDebts;
    final archived = provider.archivedDebts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(loc.debts)),
      // The empty state only applies when there is genuinely nothing here.
      // Archived debts alone used to fall into it, hiding the very debts the
      // delete flow promised were kept.
      body: debts.isEmpty && archived.isEmpty
          ? SquiState(
              pose: SquiPose.empty,
              title: loc.squiEmptyDebts,
              subtitle: loc.squiEmptyDebtsBody,
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
                        color: DebtProgressSummary.colorForLent(isDark),
                        symbol: settings.currencySymbol,
                        useDecimals: settings.currencyUseDecimals,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingMd),
                    Expanded(
                      child: _SummaryTile(
                        label: loc.youOwe,
                        amount: provider.totalIOwe,
                        color: DebtProgressSummary.colorForBorrowed(isDark),
                        symbol: settings.currencySymbol,
                        useDecimals: settings.currencyUseDecimals,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingLg),
                if (debts.isNotEmpty)
                  SectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final debt in debts) ...[
                          if (debt != debts.first) const Divider(height: 1),
                          _DebtRow(
                            debt: debt,
                            onEdit: () => showDebtForm(context, debt: debt),
                            onDelete: () => confirmDeleteDebt(context, debt),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (archived.isNotEmpty) _ArchivedDebts(debts: archived),
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

/// Debts that were archived instead of deleted, kept collapsed below the
/// active ones — the debt half of the same gap the goals list had: archiving
/// preserved the repayments but nothing ever showed them again.
class _ArchivedDebts extends StatelessWidget {
  final List<DebtModel> debts;

  const _ArchivedDebts({required this.debts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final provider = context.watch<DebtProvider>();
    final settings = context.watch<SettingsProvider>();

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingLg),
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(
            loc.archivedCount(debts.length),
            style: theme.textTheme.titleSmall,
          ),
          children: [
            for (final debt in debts)
              ListTile(
                title: Text(debt.name),
                subtitle: MaskedAmount(
                  text: NumberUtils.formatCurrency(
                    provider.repaidOf(debt.id),
                    symbol: settings.currencySymbol,
                    useDecimals: settings.currencyUseDecimals,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restore') provider.unarchiveDebt(debt.id);
                    if (value == 'purge') confirmPurgeDebt(context, debt);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'restore', child: Text(loc.restore)),
                    PopupMenuItem(
                      value: 'purge',
                      child: Text(loc.deletePermanently),
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DebtDetailScreen(debtId: debt.id),
                  ),
                ),
              ),
          ],
        ),
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
        color: color.withValues(alpha: AppConstants.tintAlpha),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            NumberUtils.formatCurrency(
              amount,
              symbol: symbol,
              useDecimals: useDecimals,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  final DebtModel debt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DebtRow({
    required this.debt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final provider = context.watch<DebtProvider>();
    final outstanding = provider.outstandingOf(debt);
    final settled = provider.isSettled(debt);
    final isDark = theme.brightness == Brightness.dark;
    final color = DebtProgressSummary.colorFor(debt, isDark);

    // Tapping the row means "look inside" — the repayments behind the bar —
    // with edit one tap further in, the same gesture the budget list uses.
    // The menu button and the Log repayment button both absorb their own
    // taps, so neither falls through to here.
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: debt.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TintedIcon(
                  icon: debt.isLent ? Icons.call_made : Icons.call_received,
                  color: color,
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
                    if (value == 'payoff') {
                      PayoffCalculatorDialog.show(context, debt, outstanding);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(loc.edit)),
                    if (debt.isBorrowed && !settled)
                      PopupMenuItem(
                        value: 'payoff',
                        child: Text(loc.payoffCalculator),
                      ),
                    PopupMenuItem(value: 'delete', child: Text(loc.delete)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            DebtProgressSummary(debt: debt),
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
