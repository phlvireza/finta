import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/transaction_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/transaction_calendar.dart';
import 'widgets/transaction_filter_sheet.dart';
import 'add_transaction_screen.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/date_group_header.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_state.dart';
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
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  TransactionFilter _filter = const TransactionFilter();
  _ViewMode _viewMode = _ViewMode.list;
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

  List<TransactionModel> _getFilteredTransactions(List<TransactionModel> all) {
    var filtered = all;

    if (_filter.type != 'all') {
      filtered = filtered.where((t) => t.type == _filter.type).toList();
    }

    final range = _filter.dateRange;
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      filtered = filtered.where((t) {
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
    }

    if (_filter.categoryIds.isNotEmpty) {
      filtered = filtered.where((t) => _filter.categoryIds.contains(t.categoryId)).toList();
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
        // In a real app we'd also search by category name, but that requires
        // joining or passing the category provider down. Note is fine for MVP.
        return note.contains(query);
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
    final formattedAmount = '${settings.currencySymbol}${tx.amount.toStringAsFixed(settings.currencyUseDecimals ? 2 : 0)}';
    final typeName = tx.isIncome ? loc.income : loc.expense;

    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.delete,
      message: 'Are you sure you want to delete this $typeName of $formattedAmount?',
      confirmText: loc.delete,
    );

    if (confirmed && mounted) {
      await context.read<TransactionProvider>().deleteTransaction(tx.id);
      
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        await context.read<BudgetProvider>().loadBudgets(payday: settings.payday);
        await context.read<AnalyticsProvider>().loadForCurrentPeriod(settings.payday);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txProvider = context.watch<TransactionProvider>();
    final allTransactions = txProvider.allTransactions;
    
    final filtered = _getFilteredTransactions(allTransactions);
    final grouped = txProvider.getGroupedTransactions(filtered);
    final loc = AppLocalizations.of(context)!;

    final isCalendarMode = _viewMode == _ViewMode.calendar;

    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final netTotal = filtered.fold<double>(
      0,
      (sum, t) => sum + (t.isIncome ? t.amount : -t.amount),
    );

    return Scaffold(
      appBar: AppBar(
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
            icon: Icon(isCalendarMode ? Icons.view_list : Icons.calendar_month),
            tooltip: isCalendarMode ? loc.all : loc.history,
            onPressed: () => setState(
              () => _viewMode = isCalendarMode ? _ViewMode.list : _ViewMode.calendar,
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
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
      ),
      body: txProvider.isLoading
          ? const SkeletonTransactionList()
          : txProvider.error != null
          ? ErrorState(
              title: 'Failed to load transactions',
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
                    if (_filter.isActive)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.spacingLg,
                          0,
                          AppConstants.spacingLg,
                          AppConstants.spacingSm,
                        ),
                        child: Wrap(
                          spacing: AppConstants.spacingSm,
                          runSpacing: AppConstants.spacingSm,
                          children: _activeFilterChips(categories),
                        ),
                      ),
                    if (filtered.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.spacingLg,
                          0,
                          AppConstants.spacingLg,
                          AppConstants.spacingSm,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            loc.transactionsSummary(
                              filtered.length,
                              '${netTotal >= 0 ? '+' : '-'} ${NumberUtils.formatCurrency(
                                netTotal.abs(),
                                symbol: settings.currencySymbol,
                                useDecimals: settings.currencyUseDecimals,
                              )}',
                            ),
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ),
                    Expanded(
                      child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: loc.noTransactionsFound,
                  subtitle: _searchQuery.isNotEmpty
                      ? loc.tryAdjustingSearch
                      : loc.noTransactionsYet,
                  action: _searchQuery.isEmpty
                      ? FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddTransactionScreen(),
                              fullscreenDialog: true,
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(loc.addTransactionCta),
                        )
                      : null,
                )
              : ListView.builder(
                  itemCount: grouped.length,
                  padding: const EdgeInsets.only(bottom: AppConstants.fabClearance),
                  itemBuilder: (context, index) {
                final dateLabel = grouped.keys.elementAt(index);
                final txList = grouped[dateLabel]!;

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
                      child: DateGroupHeader(label: dateLabel, transactions: txList),
                    ),
                    ...txList.map((tx) {
                      return Slidable(
                        key: ValueKey(tx.id),
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          extentRatio: 0.25,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _deleteTransaction(tx),
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              icon: Icons.delete,
                              label: loc.delete,
                            ),
                          ],
                        ),
                        child: TransactionTile(transaction: tx),
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

  List<Widget> _activeFilterChips(CategoryProvider categories) {
    final loc = AppLocalizations.of(context)!;
    final chips = <Widget>[];

    if (_filter.dateRange != null) {
      final r = _filter.dateRange!;
      chips.add(InputChip(
        label: Text(AppDateUtils.formatPeriodRange(r.start, r.end)),
        onDeleted: () => setState(() => _filter = _filter.copyWith(clearDateRange: true)),
      ));
    }
    if (_filter.type != 'all') {
      chips.add(InputChip(
        label: Text(_filter.type == 'income' ? loc.income : loc.expense),
        onDeleted: () => setState(() => _filter = _filter.copyWith(type: 'all')),
      ));
    }
    for (final id in _filter.categoryIds) {
      final name = categories.getCategoryById(id)?.name ?? loc.unknown;
      chips.add(InputChip(
        label: Text(name),
        onDeleted: () => setState(() {
          final updated = Set<String>.from(_filter.categoryIds)..remove(id);
          _filter = _filter.copyWith(categoryIds: updated);
        }),
      ));
    }
    if (_filter.minAmount != null || _filter.maxAmount != null) {
      chips.add(InputChip(
        label: Text(loc.amountRange),
        onDeleted: () => setState(() => _filter = _filter.copyWith(
              clearMinAmount: true,
              clearMaxAmount: true,
            )),
      ));
    }
    return chips;
  }
}
