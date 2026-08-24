import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/transaction_calendar.dart';
import 'widgets/transaction_filter_sheet.dart';
import 'add_transaction_screen.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/squi/squi_state.dart';
import '../../core/constants/squi.dart';
import '../../widgets/date_group_header.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_state.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/section_card.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../l10n/app_localizations.dart';

enum _ViewMode { list, calendar }

/// Full history screen with search, filtering, swipe-to-delete, and a
/// calendar view. The calendar used to live on the dashboard, occupying
/// the at-a-glance slot for what is fundamentally a browsing tool — it
/// belongs here, as a view mode on the ledger it browses.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  TransactionFilter _filter = const TransactionFilter();
  _ViewMode _viewMode = _ViewMode.list;
  final Set<String> _selectedIds = {};
  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Start loading transactions once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TransactionProvider>().loadAllTransactions();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _getFilteredTransactions(
    List<TransactionModel> all,
    CategoryProvider categories,
    AccountProvider accounts,
  ) {
    var filtered = all;

    if (_filter.type != 'all') {
      filtered = filtered.where((t) => t.type == _filter.type).toList();
    }

    final range = _filter.dateRange;
    if (range != null) {
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      filtered = filtered.where((t) {
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
    }

    if (_filter.categoryIds.isNotEmpty) {
      filtered = filtered
          .where((t) => _filter.categoryIds.contains(t.categoryId))
          .toList();
    }

    if (_filter.accountIds.isNotEmpty) {
      filtered = filtered
          .where((t) => _filter.accountIds.contains(t.accountId))
          .toList();
    }

    if (_filter.minAmount != null) {
      filtered = filtered.where((t) => t.amount >= _filter.minAmount!).toList();
    }
    if (_filter.maxAmount != null) {
      filtered = filtered.where((t) => t.amount <= _filter.maxAmount!).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((t) {
        final note = t.note?.toLowerCase() ?? '';
        final merchant = t.merchant?.toLowerCase() ?? '';
        final categoryName =
            categories.getCategoryById(t.categoryId)?.name.toLowerCase() ?? '';
        final accountName =
            accounts.getAccountById(t.accountId)?.name.toLowerCase() ?? '';
        // Typing a bare number (e.g. "45000") should find that amount
        // whether or not the user included decimals.
        final amountString = t.amount.toStringAsFixed(0);
        return note.contains(query) ||
            merchant.contains(query) ||
            categoryName.contains(query) ||
            accountName.contains(query) ||
            amountString.contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _openFilterSheet() async {
    final settings = context.read<SettingsProvider>();
    final currentPeriod = AppDateUtils.getCurrentPeriod(settings.payday);
    final previousPeriod = AppDateUtils.getPreviousPeriod(currentPeriod);
    final result = await TransactionFilterSheet.show(
      context,
      initial: _filter,
      currentPeriod: currentPeriod,
      previousPeriod: previousPeriod,
    );
    if (result != null) {
      setState(() => _filter = result);
    }
  }

  Future<void> _deleteTransaction(TransactionModel tx) async {
    final loc = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final formattedAmount = NumberUtils.formatCurrency(
      tx.amount,
      symbol: settings.currencySymbol,
      useDecimals: settings.currencyUseDecimals,
    );
    final typeName = tx.isIncome ? loc.income : loc.expense;

    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.delete,
      message: loc.confirmDeleteTransactionMessage(typeName, formattedAmount),
      confirmText: loc.delete,
    );

    if (confirmed && mounted) {
      await context.read<TransactionProvider>().deleteTransaction(tx.id);

      if (mounted) {
        final settings = context.read<SettingsProvider>();
        await context.read<BudgetProvider>().loadBudgets(
          payday: settings.payday,
        );
        if (!mounted) return;
        await context.read<AnalyticsProvider>().loadForCurrentPeriod(
          settings.payday,
        );
        if (!mounted) return;
        await context.read<AccountProvider>().loadAccounts();
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// Reloads every provider whose numbers a bulk action could have moved —
  /// same set [_deleteTransaction] refreshes after a single delete.
  /// Kept manually in sync since bulk and single-delete are separate call sites.
  Future<void> _reloadAfterBulkChange() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    await context.read<TransactionProvider>().loadTransactions(
      payday: settings.payday,
    );
    if (!mounted) return;
    await context.read<BudgetProvider>().loadBudgets(payday: settings.payday);
    if (!mounted) return;
    await context.read<AnalyticsProvider>().loadForCurrentPeriod(
      settings.payday,
    );
    if (!mounted) return;
    await context.read<AccountProvider>().loadAccounts();
  }

  Future<void> _bulkDelete() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.delete,
      message: loc.confirmBulkDelete(_selectedIds.length),
      confirmText: loc.delete,
    );
    if (!confirmed || !mounted) return;

    final txProvider = context.read<TransactionProvider>();
    for (final id in _selectedIds.toList()) {
      await txProvider.deleteTransaction(id);
    }
    setState(() => _selectedIds.clear());
    await _reloadAfterBulkChange();
  }

  /// Duplicates every selected non-transfer transaction with today's date.
  /// Transfers are skipped — duplicating one leg of a linked pair would
  /// desync it, and a duplicate transfer needs its own pair of accounts
  /// chosen anyway, not a blind copy.
  Future<void> _bulkDuplicate() async {
    final loc = AppLocalizations.of(context)!;
    final txProvider = context.read<TransactionProvider>();
    final selected = txProvider.allTransactions
        .where((t) => _selectedIds.contains(t.id) && !t.isTransfer)
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.cannotDuplicateTransfers)));
      return;
    }

    for (final tx in selected) {
      await txProvider.addTransaction(
        type: tx.type,
        amount: tx.amount,
        categoryId: tx.categoryId,
        accountId: tx.accountId,
        merchant: tx.merchant,
        note: tx.note,
        date: DateTime.now(),
      );
    }
    setState(() => _selectedIds.clear());
    await _reloadAfterBulkChange();
  }

  /// Recategorizes every selected non-transfer transaction at once.
  /// Requires them to share a single income/expense type, since the
  /// category picker itself is type-scoped — mixed selections are asked
  /// to narrow down rather than silently splitting into two operations.
  Future<void> _bulkRecategorize() async {
    final loc = AppLocalizations.of(context)!;
    final txProvider = context.read<TransactionProvider>();
    final selected = txProvider.allTransactions
        .where((t) => _selectedIds.contains(t.id) && !t.isTransfer)
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.cannotRecategorizeTransfers)));
      return;
    }
    final isIncome = selected.first.isIncome;
    if (selected.any((t) => t.isIncome != isIncome)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.selectSameTypeToRecategorize)));
      return;
    }

    final newCategoryId = await _BulkRecategorizeSheet.show(
      context,
      isIncome: isIncome,
    );
    if (newCategoryId == null || !mounted) return;

    for (final tx in selected) {
      await txProvider.updateTransaction(
        tx.copyWith(categoryId: newCategoryId),
      );
    }
    setState(() => _selectedIds.clear());
    await _reloadAfterBulkChange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txProvider = context.watch<TransactionProvider>();
    final allTransactions = txProvider.allTransactions;
    final categories = context.watch<CategoryProvider>();
    final accounts = context.watch<AccountProvider>();

    final filtered = _getFilteredTransactions(
      allTransactions,
      categories,
      accounts,
    );
    final grouped = txProvider.getGroupedTransactions(filtered);
    final loc = AppLocalizations.of(context)!;

    final isCalendarMode = _viewMode == _ViewMode.calendar;

    final settings = context.watch<SettingsProvider>();
    final netTotal = filtered.fold<double>(
      0,
      (sum, t) => sum + (t.isIncome ? t.amount : -t.amount),
    );

    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIds.clear()),
              ),
              title: Text(loc.selectedCount(_selectedIds.length)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: loc.duplicate,
                  onPressed: _bulkDuplicate,
                ),
                IconButton(
                  icon: const Icon(Icons.category_outlined),
                  tooltip: loc.recategorize,
                  onPressed: _bulkRecategorize,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: loc.delete,
                  onPressed: _bulkDelete,
                ),
              ],
            )
          : AppBar(
              title: Text(loc.history),
              actions: [
                IconButton(
                  icon: Badge(
                    isLabelVisible: _filter.isActive,
                    smallSize: 8,
                    child: const Icon(Icons.tune),
                  ),
                  tooltip: loc.filters,
                  onPressed: _openFilterSheet,
                ),
                IconButton(
                  icon: Icon(
                    isCalendarMode ? Icons.view_list : Icons.calendar_month,
                  ),
                  tooltip: isCalendarMode ? loc.all : loc.history,
                  onPressed: () => setState(
                    () => _viewMode = isCalendarMode
                        ? _ViewMode.list
                        : _ViewMode.calendar,
                  ),
                ),
              ],
              bottom: isCalendarMode
                  ? null
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(64),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.spacingLg,
                          0,
                          AppConstants.spacingLg,
                          AppConstants.spacingLg,
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: loc.searchNotes,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                      ),
                    ),
            ),
      body: txProvider.isLoading
          ? const SkeletonTransactionList()
          : txProvider.error != null
          ? ErrorState(
              title: loc.errorFailedToLoadData,
              message: txProvider.error!,
              onRetry: () => txProvider.loadAllTransactions(),
            )
          : isCalendarMode
          ? Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: TransactionCalendar(transactions: allTransactions),
            )
          : Column(
              children: [
                if (_filter.isActive || filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.spacingLg,
                      AppConstants.spacingSm,
                      AppConstants.spacingLg,
                      AppConstants.spacingSm,
                    ),
                    child: SectionCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingLg,
                        vertical: AppConstants.spacingMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (filtered.isNotEmpty)
                            Text(
                              loc.transactionsSummary(
                                filtered.length,
                                '${netTotal >= 0 ? '+' : '-'} ${NumberUtils.formatCurrency(netTotal.abs(), symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals)}',
                              ),
                              style: theme.textTheme.labelMedium,
                            ),
                          if (_filter.isActive) ...[
                            if (filtered.isNotEmpty)
                              const SizedBox(height: AppConstants.spacingSm),
                            Wrap(
                              spacing: AppConstants.spacingSm,
                              runSpacing: AppConstants.spacingSm,
                              children: _activeFilterChips(
                                categories,
                                accounts,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? (txProvider.hasAnyTransactions == false &&
                                _searchQuery.isEmpty &&
                                !_filter.isActive
                            ? SquiState(
                                pose: SquiPose.empty,
                                title: loc.squiEmptyTransactions,
                                subtitle: loc.squiEmptyTransactionsBody,
                                action: FilledButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AddTransactionScreen(),
                                      fullscreenDialog: true,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: Text(loc.addTransactionCta),
                                ),
                              )
                            : EmptyState(
                                icon: Icons.search_off,
                                title: loc.noTransactionsFound,
                                subtitle: _searchQuery.isNotEmpty
                                    ? loc.tryAdjustingSearch
                                    : loc.noTransactionsYet,
                                action: _searchQuery.isEmpty
                                    ? FilledButton.icon(
                                        onPressed: () =>
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const AddTransactionScreen(),
                                                fullscreenDialog: true,
                                              ),
                                            ),
                                        icon: const Icon(Icons.add),
                                        label: Text(loc.addTransactionCta),
                                      )
                                    : null,
                              ))
                      : ListView.builder(
                          itemCount: grouped.length,
                          padding: const EdgeInsets.only(
                            bottom: AppConstants.fabClearance,
                          ),
                          itemBuilder: (context, index) {
                            final groupDate = grouped.keys.elementAt(index);
                            final txList = grouped[groupDate]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppConstants.spacingLg,
                                    AppConstants.spacingLg,
                                    AppConstants.spacingLg,
                                    0,
                                  ),
                                  child: DateGroupHeader(
                                    date: groupDate,
                                    transactions: txList,
                                  ),
                                ),
                                ...txList.map((tx) {
                                  final isSelected = _selectedIds.contains(
                                    tx.id,
                                  );
                                  // Long-press enters (or extends) multi-select on any
                                  // tile, selection mode or not — the same gesture
                                  // Gmail/Photos use, so there's no separate "enter
                                  // selection mode" affordance to discover.
                                  final row = GestureDetector(
                                    onLongPress: () => _toggleSelection(tx.id),
                                    child: Container(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                                .withValues(alpha: 0.08)
                                          : null,
                                      child: Row(
                                        children: [
                                          if (_selectionMode)
                                            Checkbox(
                                              value: isSelected,
                                              onChanged: (_) =>
                                                  _toggleSelection(tx.id),
                                            ),
                                          Expanded(
                                            child: TransactionTile(
                                              transaction: tx,
                                              onTap: _selectionMode
                                                  ? () =>
                                                        _toggleSelection(tx.id)
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  // Swipe-to-delete is disabled during multi-select —
                                  // a horizontal drag gesture there would fight with
                                  // the tap-to-toggle interaction on every tile.
                                  if (_selectionMode) return row;

                                  return Slidable(
                                    key: ValueKey(tx.id),
                                    endActionPane: ActionPane(
                                      motion: const ScrollMotion(),
                                      extentRatio: 0.25,
                                      children: [
                                        SlidableAction(
                                          onPressed: (_) =>
                                              _deleteTransaction(tx),
                                          backgroundColor:
                                              theme.colorScheme.error,
                                          foregroundColor:
                                              theme.colorScheme.onError,
                                          icon: Icons.delete,
                                          label: loc.delete,
                                        ),
                                      ],
                                    ),
                                    child: row,
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  List<Widget> _activeFilterChips(
    CategoryProvider categories,
    AccountProvider accounts,
  ) {
    final loc = AppLocalizations.of(context)!;
    final chips = <Widget>[];

    if (_filter.dateRange != null) {
      final r = _filter.dateRange!;
      chips.add(
        InputChip(
          label: Text(AppDateUtils.formatPeriodRange(r.start, r.end)),
          onDeleted: () =>
              setState(() => _filter = _filter.copyWith(clearDateRange: true)),
        ),
      );
    }
    if (_filter.type != 'all') {
      chips.add(
        InputChip(
          label: Text(_filter.type == 'income' ? loc.income : loc.expense),
          onDeleted: () =>
              setState(() => _filter = _filter.copyWith(type: 'all')),
        ),
      );
    }
    for (final id in _filter.categoryIds) {
      final name = categories.getCategoryById(id)?.name ?? loc.unknown;
      chips.add(
        InputChip(
          label: Text(name),
          onDeleted: () => setState(() {
            final updated = Set<String>.from(_filter.categoryIds)..remove(id);
            _filter = _filter.copyWith(categoryIds: updated);
          }),
        ),
      );
    }
    for (final id in _filter.accountIds) {
      final name = accounts.getAccountById(id)?.name ?? loc.unknown;
      chips.add(
        InputChip(
          label: Text(name),
          onDeleted: () => setState(() {
            final updated = Set<String>.from(_filter.accountIds)..remove(id);
            _filter = _filter.copyWith(accountIds: updated);
          }),
        ),
      );
    }
    if (_filter.minAmount != null || _filter.maxAmount != null) {
      chips.add(
        InputChip(
          label: Text(loc.amountRange),
          onDeleted: () => setState(
            () => _filter = _filter.copyWith(
              clearMinAmount: true,
              clearMaxAmount: true,
            ),
          ),
        ),
      );
    }
    return chips;
  }
}

/// Category picker for bulk recategorize — a flat, type-scoped list with no
/// create-new, since this is a one-off action on an already-selected batch,
/// not the primary entry-form picker.
///
/// Presented through [PickerSheet] so it sizes and reads exactly like the
/// entry-form picker; the search field is not autofocused here, because the
/// list is the answer to "which category" far more often than typing is.
class _BulkRecategorizeSheet extends StatefulWidget {
  final bool isIncome;

  const _BulkRecategorizeSheet({required this.isIncome});

  static Future<String?> show(BuildContext context, {required bool isIncome}) {
    return PickerSheet.show<String>(
      context,
      builder: (_) => _BulkRecategorizeSheet(isIncome: isIncome),
    );
  }

  @override
  State<_BulkRecategorizeSheet> createState() => _BulkRecategorizeSheetState();
}

class _BulkRecategorizeSheetState extends State<_BulkRecategorizeSheet> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final categories = context.watch<CategoryProvider>();
    final List<CategoryModel> options = widget.isIncome
        ? categories.incomeCategories
        : categories.expenseCategories;

    final query = _searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? options
        : options.where((c) => c.name.toLowerCase().contains(query)).toList();

    return PickerSheet(
      title: loc.recategorize,
      pinnedHeader: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: loc.searchCategories,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      emptyState: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXxl),
        child: Text(loc.noCategoriesFound, style: theme.textTheme.bodyMedium),
      ),
      children: filtered
          .map(
            (cat) => ListTile(
              leading: Icon(cat.iconData, color: cat.colorValue),
              title: Text(cat.name),
              onTap: () => Navigator.of(context).pop(cat.id),
            ),
          )
          .toList(),
    );
  }
}
