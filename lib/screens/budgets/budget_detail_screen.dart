import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/budget_display.dart';
import '../../core/utils/budget_entry.dart';
import '../../models/budget_model.dart';
import '../../models/transaction_model.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/form_sheet.dart';
import '../../widgets/date_group_header.dart';
import '../../widgets/skeleton_box.dart';
import '../transactions/widgets/quick_add_sheet.dart';
import '../transactions/widgets/transaction_tile.dart';
import 'budget_actions.dart';
import 'widgets/budget_category_picker_sheet.dart';
import 'widgets/budget_form.dart';
import 'widgets/budget_progress_bar.dart';
import '../../l10n/app_localizations.dart';

/// Everything behind one budget's progress bar: the same header the lists
/// show, plus the transactions that produced the number.
///
/// The bar on its own only ever answered "how much" — this screen answers
/// "on what", which is the question that follows it, and puts edit one tap
/// away instead of making the row's tap gesture mean "edit" (it now means
/// "look inside", with edit in the app bar).
class BudgetDetailScreen extends StatefulWidget {
  final String budgetId;

  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  List<TransactionModel>? _transactions;
  String? _error;

  /// The status the loaded list belongs to. [BudgetProvider] rebuilds its
  /// `BudgetStatus` objects from scratch on every `loadBudgets`, and every
  /// mutation that can change this budget's spending goes through one — a
  /// new transaction, an edit, a rollover recalculation. So a status that is
  /// no longer the *same object* is the signal that the list is stale.
  BudgetStatus? _loadedFor;

  /// Set for the frame between a confirmed delete and this route popping.
  /// `deleteBudget` notifies immediately, which drops this budget from
  /// `budgetStatuses` — without the flag, the missing-status branch in
  /// [build] would flash "failed to load" on the way out.
  bool _deleting = false;

  /// Runs on mount and again whenever [BudgetProvider] notifies — `build`
  /// watches it, which is what registers the dependency that brings us back
  /// here. Read (not watch) because this is not a build method.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final status = context.read<BudgetProvider>().budgetStatuses[widget.budgetId];
    if (status != null && !identical(status, _loadedFor)) {
      _loadedFor = status;
      _load(status);
    }
  }

  Future<void> _load(BudgetStatus status) async {
    final provider = context.read<BudgetProvider>();
    try {
      final items = await provider.transactionsFor(
        status.budget,
        period: status.period,
      );
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

  /// Logs spending against this budget without leaving the screen.
  ///
  /// The category is decided by [resolveBudgetEntryCategory]: a single-category
  /// budget prefills straight away, a group budget asks which of *its own*
  /// categories first, and an overall budget prefills nothing because every
  /// expense already counts toward it.
  Future<void> _addExpense(BudgetModel budget) async {
    final selectable = context.read<CategoryProvider>().expenseCategories;
    final entry = resolveBudgetEntryCategory(
      budget: budget,
      selectableCategoryIds: selectable.map((c) => c.id).toSet(),
    );

    var categoryId = entry.categoryId;
    if (entry.choices.isNotEmpty) {
      categoryId = await BudgetCategoryPickerSheet.show(
        context,
        categoryIds: entry.choices,
      );
      // Dismissed without choosing — don't open the form on a guess.
      if (categoryId == null || !mounted) return;
    }
    if (!mounted) return;

    await QuickAddSheet.show(context, initialCategoryId: categoryId);
    // Nothing to reload here: saving calls `loadBudgets`, which replaces this
    // budget's status object and trips the identity check in
    // didChangeDependencies — the same path an edit from elsewhere takes.
  }

  Future<void> _edit() async {
    await FormSheet.show(
      context,
      builder: (_) => BudgetForm(budgetIdToEdit: widget.budgetId),
    );
    // Saving replaces the status object, so didChangeDependencies already
    // has the reload covered. Dismissing without saving leaves it identical
    // and correctly reloads nothing.
  }

  Future<void> _delete(String title) async {
    final navigator = Navigator.of(context);
    setState(() => _deleting = true);

    final deleted = await confirmDeleteBudget(
      context,
      budgetId: widget.budgetId,
      title: title,
    );

    if (deleted) {
      navigator.pop();
    } else if (mounted) {
      // Cancelled, or the delete failed and the helper has already said so.
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final categories = context.watch<CategoryProvider>();
    final status = context.watch<BudgetProvider>().budgetStatuses[widget.budgetId];

    // Only active budgets get a status. Deleting the budget from elsewhere,
    // or a one-off budget being retired while this screen is open, lands
    // here rather than on a null dereference — but a delete started *here*
    // is already on its way out, so it gets a blank frame instead of an
    // error it would only see for an instant.
    if (status == null) {
      if (_deleting) return const Scaffold(body: SizedBox.shrink());
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(title: loc.errorFailedToLoadData),
      );
    }

    final display = resolveBudgetDisplay(
      budget: status.budget,
      categories: categories,
      loc: loc,
      fallbackColor: theme.colorScheme.primary,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(display.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: loc.editBudget,
            onPressed: _edit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: theme.colorScheme.error,
            tooltip: loc.delete,
            onPressed: _deleting ? null : () => _delete(display.title),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppConstants.fabClearance),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingMd,
              AppConstants.spacingLg,
              AppConstants.spacingSm,
            ),
            child: BudgetProgressBar(
              status: status,
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
            child: Text(
              AppDateUtils.formatPeriodRange(status.period.start, status.period.end),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          // Always offered, including once the budget is exceeded — going over
          // is exactly when the next expense still needs recording.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addExpense(status.budget),
                icon: const Icon(Icons.add, size: 20),
                label: Text(loc.addExpense),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
            child: Text(loc.transactions, style: theme.textTheme.titleMedium),
          ),
          ..._buildTransactionSection(context, loc, status),
        ],
      ),
    );
  }

  List<Widget> _buildTransactionSection(
    BuildContext context,
    AppLocalizations loc,
    BudgetStatus status,
  ) {
    // Both branches below need an explicit height: they are children of a
    // scrolling ListView, so they are laid out unbounded, and neither a
    // ListView (the skeleton) nor a full-height Column (ErrorState) can
    // size itself in infinite space.
    if (_error != null) {
      return [
        SizedBox(
          height: 320,
          child: ErrorState(
            title: loc.errorFailedToLoadData,
            message: _error,
            onRetry: () => _load(status),
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
          padding: const EdgeInsets.only(top: AppConstants.spacingXxl),
          child: EmptyState(
            icon: Icons.receipt_long_outlined,
            title: loc.noTransactionsFound,
            subtitle: AppDateUtils.formatPeriodRange(
              status.period.start,
              status.period.end,
            ),
          ),
        ),
      ];
    }

    final grouped = context.read<TransactionProvider>().getGroupedTransactions(transactions);
    return grouped.entries
        .map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    AppConstants.spacingMd,
                    AppConstants.spacingLg,
                    0,
                  ),
                  child: DateGroupHeader(label: entry.key, transactions: entry.value),
                ),
                ...entry.value.map(
                  (tx) => TransactionTile(transaction: tx, dense: true),
                ),
              ],
            ))
        .toList();
  }
}
