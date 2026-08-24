import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/debt_model.dart';
import '../../models/transaction_model.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/date_group_header.dart';
import '../../widgets/squi/squi_state.dart';
import '../../core/constants/squi.dart';
import '../../widgets/error_state.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/section_card.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/widgets/transaction_tile.dart';
import 'debt_actions.dart';
import 'debts_list_screen.dart';
import 'widgets/debt_progress_summary.dart';
import 'widgets/payoff_calculator_dialog.dart';
import 'widgets/repayment_sheet.dart';
import '../../l10n/app_localizations.dart';

/// Everything behind one debt's progress bar: the same summary the card
/// shows, plus the repayments that produced the number.
///
/// The bar on its own only ever answered "how much is left" — this screen
/// answers "what has been paid, when, and through which wallet". Repayments
/// are ordinary transactions, so the rows here are the real ones: tapping one
/// opens it for editing, and the header moves when it does.
class DebtDetailScreen extends StatefulWidget {
  final String debtId;

  const DebtDetailScreen({super.key, required this.debtId});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  List<TransactionModel>? _transactions;
  String? _error;

  /// The repaid figure the loaded list belongs to. `DebtProvider` recomputes
  /// it from the tagged transactions on every `loadDebts`, so a changed total
  /// means a repayment was added, edited or removed and the list underneath
  /// it is stale. Edits that leave the total alone (a reworded note) are
  /// covered by the explicit reload in [_openTransaction].
  double? _loadedFor;

  /// Set for the frame between a confirmed delete and this route popping —
  /// without it the missing-debt branch in [build] would flash an error on
  /// the way out.
  bool _deleting = false;

  /// Runs on mount and again whenever [DebtProvider] notifies, because
  /// `build` watches it. Read (not watch) here — this is not a build method.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<DebtProvider>();
    if (provider.getDebtById(widget.debtId) == null) return;
    final repaid = provider.repaidOf(widget.debtId);
    if (_loadedFor != repaid || _transactions == null) {
      _loadedFor = repaid;
      _load();
    }
  }

  Future<void> _load() async {
    final provider = context.read<DebtProvider>();
    try {
      final items = await provider.transactionsFor(widget.debtId);
      if (!mounted) return;
      setState(() {
        _transactions = items;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Opens a repayment for editing. `AddTransactionScreen`'s own
  /// cross-provider refresh covers transactions, budgets, accounts and
  /// analytics but not debts, so reload the debt here — otherwise editing a
  /// repayment's amount would move the list without moving the header.
  Future<void> _openTransaction(TransactionModel transaction) async {
    final provider = context.read<DebtProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(editTransaction: transaction),
      ),
    );
    if (!mounted) return;
    await provider.loadDebts();
    if (!mounted) return;
    _loadedFor = provider.repaidOf(widget.debtId);
    await _load();
  }

  Future<void> _delete(DebtModel debt) async {
    final navigator = Navigator.of(context);
    setState(() => _deleting = true);

    final deleted = await confirmDeleteDebt(context, debt);

    if (deleted) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final provider = context.watch<DebtProvider>();
    final debt = provider.getDebtById(widget.debtId);

    // Deleting a debt with no repayments removes the row outright. A delete
    // started here is already on its way out, so it gets a blank frame rather
    // than an error it would see for an instant.
    if (debt == null) {
      if (_deleting) return const Scaffold(body: SizedBox.shrink());
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(title: loc.errorFailedToLoadData),
      );
    }

    final outstanding = provider.outstandingOf(debt);
    final settled = provider.isSettled(debt);

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.name),
        actions: [
          if (debt.isBorrowed && !settled)
            IconButton(
              icon: const Icon(Icons.calculate_outlined),
              tooltip: loc.payoffCalculator,
              onPressed: () =>
                  PayoffCalculatorDialog.show(context, debt, outstanding),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: loc.editDebt,
            onPressed: () => DebtsListScreen.showDebtForm(context, debt: debt),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: theme.colorScheme.error,
            tooltip: loc.delete,
            onPressed: _deleting ? null : () => _delete(debt),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          AppConstants.spacingMd,
          AppConstants.spacingLg,
          AppConstants.fabClearance,
        ),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      debt.isLent ? Icons.call_made : Icons.call_received,
                      size: 18,
                      color: DebtProgressSummary.colorFor(
                        debt,
                        theme.brightness == Brightness.dark,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Text(
                      debt.isLent ? loc.debtTypeLent : loc.debtTypeBorrowed,
                      style: theme.textTheme.bodySmall,
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
          const SizedBox(height: AppConstants.spacingLg),
          Text(loc.repayments, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppConstants.spacingMd),
          ..._buildRepaymentSection(context, loc),
        ],
      ),
    );
  }

  List<Widget> _buildRepaymentSection(
    BuildContext context,
    AppLocalizations loc,
  ) {
    // Both branches below need an explicit height: they are children of a
    // scrolling ListView, so they are laid out unbounded, and neither a
    // ListView (the skeleton) nor a full-height Column (ErrorState) can size
    // itself in infinite space.
    if (_error != null) {
      return [
        SizedBox(
          height: 320,
          child: ErrorState(
            title: loc.errorFailedToLoadData,
            message: _error,
            onRetry: _load,
          ),
        ),
      ];
    }

    final transactions = _transactions;
    if (transactions == null) {
      return const [
        SizedBox(height: 320, child: SkeletonTransactionList(count: 4)),
      ];
    }

    if (transactions.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AppConstants.spacingXl),
          child: SquiState(
            pose: SquiPose.empty,
            title: loc.squiEmptyRepayments,
            subtitle: loc.squiEmptyRepaymentsBody,
          ),
        ),
      ];
    }

    final grouped = context.read<TransactionProvider>().getGroupedTransactions(
      transactions,
    );
    return grouped.entries
        .map(
          (entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateGroupHeader(date: entry.key, transactions: entry.value),
              ...entry.value.map(
                (tx) => TransactionTile(
                  transaction: tx,
                  dense: true,
                  onTap: () => _openTransaction(tx),
                ),
              ),
            ],
          ),
        )
        .toList();
  }
}
