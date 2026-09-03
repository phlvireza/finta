import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'account_provider.dart';
import 'analytics_provider.dart';
import 'budget_provider.dart';
import 'debt_provider.dart';
import 'goal_provider.dart';
import 'settings_provider.dart';
import 'transaction_provider.dart';

/// Reloads every provider whose numbers a posted, edited or deleted
/// transaction can move.
///
/// Writing a transaction changes four things at once — the period list, the
/// budget bars, the account balances and every analytics figure — and none of
/// them recompute themselves. Each mutation site used to spell that fan-out
/// out by hand, and with a dozen copies they had drifted: they disagreed on
/// the provider set, on the order, and on where the `mounted` guards went.
/// A CSV import skipped budgets and analytics entirely; purging a debt
/// skipped [TransactionProvider.loadAllTransactions] where purging a goal
/// did it. Those were the bugs that motivated this function.
///
/// Every provider is read *before* the first `await`, so this never touches
/// the [BuildContext] across an async gap — which is why it takes no
/// `mounted` checks and needs none from callers between the awaits.
///
/// The optional flags exist because the extras genuinely are optional, not
/// to make the chain configurable for its own sake:
///
/// - [allTransactions] reloads the unbounded list behind the calendar,
///   subscription detection and CSV export. Only worth it when rows outside
///   the current period changed — a bulk delete, an import, a purge.
/// - [goals] / [debts] reload progress that is derived from transactions
///   tagged with a `goalId` / `debtId`.
///
/// Deliberately *not* used by the narrow sites: stopping a recurring template
/// only unlinks occurrences (badges change, no money moves), and deleting a
/// single transaction goes through [TransactionProvider.deleteTransaction],
/// which already updates its own lists in memory. Reaching for the full chain
/// there would be wasted queries, not extra safety.
Future<void> refreshAfterLedgerMutation(
  BuildContext context, {
  bool allTransactions = false,
  bool goals = false,
  bool debts = false,
}) {
  return ledgerRefresher(
    context,
    allTransactions: allTransactions,
    goals: goals,
    debts: debts,
  )();
}

/// Reads the providers now and returns the reload to run later.
///
/// For the mutation sites that must resolve their providers *before* the
/// write they are about to await — the goal and debt purges do this so a
/// screen that pops itself on delete still gets its numbers recomputed.
/// Calling [refreshAfterLedgerMutation] after such an await would instead
/// have to give up on an unmounted context and skip the reload entirely.
Future<void> Function() ledgerRefresher(
  BuildContext context, {
  bool allTransactions = false,
  bool goals = false,
  bool debts = false,
}) {
  final payday = context.read<SettingsProvider>().payday;
  final transactions = context.read<TransactionProvider>();
  final budgets = context.read<BudgetProvider>();
  final accounts = context.read<AccountProvider>();
  final analytics = context.read<AnalyticsProvider>();
  final goalProvider = goals ? context.read<GoalProvider>() : null;
  final debtProvider = debts ? context.read<DebtProvider>() : null;

  return () async {
    await transactions.loadTransactions(payday: payday);
    if (allTransactions) await transactions.loadAllTransactions();
    await budgets.loadBudgets(payday: payday);
    await accounts.loadAccounts();
    await analytics.loadForCurrentPeriod(payday);
    await goalProvider?.loadGoals();
    await debtProvider?.loadDebts();
  };
}
