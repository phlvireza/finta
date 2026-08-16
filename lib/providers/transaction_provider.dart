import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../core/database/seed_data.dart';
import '../core/utils/date_utils.dart';
import '../core/constants/app_constants.dart';

/// Manages transaction state — CRUD, balance calculations, filtered lists.
class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repository;
  static const _uuid = Uuid();

  TransactionProvider({TransactionRepository? repository})
      : _repository = repository ?? TransactionRepository();

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _allTransactions = [];
  bool _isLoading = false;
  String? _error; // Store latest error message

  // Period-based calculations
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _previousTotalIncome = 0;
  double _previousTotalExpense = 0;
  ({DateTime start, DateTime end})? _period;
  int _periodOffset = 0;

  /// Whether [date] falls inside the currently loaded period. Every
  /// mutation below must gate on this before touching `_transactions` or
  /// the running totals — otherwise a backdated or forward-dated entry
  /// corrupts the current period's numbers until the next full reload.
  bool _inPeriod(DateTime date) {
    final period = _period;
    if (period == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(period.start) && !d.isAfter(period.end);
  }

  static int _byDateDesc(TransactionModel a, TransactionModel b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
  }

  List<TransactionModel> get transactions => _transactions;

  /// The newest few transactions **in the loaded period**.
  ///
  /// This used to be its own query — `getRecent(limit)`, which had no WHERE
  /// clause at all, so it returned the newest rows in the database and the
  /// dashboard kept showing today's entries after the user stepped back to
  /// a past period. `_transactions` is already period-scoped and already
  /// ordered by [_byDateDesc], so deriving from it fixes the leak and drops
  /// five redundant round-trips.
  List<TransactionModel> get recentTransactions =>
      _transactions.take(AppConstants.recentTransactionCount).toList();

  List<TransactionModel> get allTransactions => _allTransactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  double get previousTotalIncome => _previousTotalIncome;
  double get previousTotalExpense => _previousTotalExpense;
  double get balance => _totalIncome - _totalExpense;
  ({DateTime start, DateTime end})? get period => _period;

  /// How many periods back from "now" the loaded period is. 0 = current;
  /// negative = a past period. Never positive — there's nothing to show
  /// for a period that hasn't happened yet.
  int get periodOffset => _periodOffset;
  bool get isViewingCurrentPeriod => _periodOffset == 0;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Load all transactions and calculate totals for the period at
  /// [offset] periods back from the current one (0 = current, -1 = the
  /// one before it, …). Defaults to whatever period was last loaded so a
  /// plain refresh doesn't reset the user back to "now".
  Future<void> loadTransactions({required int payday, int? offset}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _periodOffset = (offset ?? _periodOffset).clamp(-1000000, 0);
      var period = AppDateUtils.getCurrentPeriod(payday);
      for (var i = 0; i > _periodOffset; i--) {
        period = AppDateUtils.getPreviousPeriod(period);
      }
      _period = period;
      _transactions = await _repository.getByDateRange(period.start, period.end);

      _totalIncome = await _repository.getSumByTypeAndDateRange(
        'income',
        period.start,
        period.end,
      );
      _totalExpense = await _repository.getSumByTypeAndDateRange(
        'expense',
        period.start,
        period.end,
      );

      // Owned here (rather than borrowed from AnalyticsProvider) so the
      // dashboard's "vs last period" always compares against the same
      // period it's showing — not whatever period the Analytics screen
      // happens to have selected.
      final previousPeriod = AppDateUtils.getPreviousPeriod(period);
      _previousTotalIncome = await _repository.getSumByTypeAndDateRange(
        'income',
        previousPeriod.start,
        previousPeriod.end,
      );
      _previousTotalExpense = await _repository.getSumByTypeAndDateRange(
        'expense',
        previousPeriod.start,
        previousPeriod.end,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Step the loaded period one back in time (e.g. this month → last month).
  Future<void> goToPreviousPeriod({required int payday}) =>
      loadTransactions(payday: payday, offset: _periodOffset - 1);

  /// Step the loaded period one forward. A no-op once already at the
  /// current period — there's nothing to show for the future.
  Future<void> goToNextPeriod({required int payday}) {
    if (_periodOffset >= 0) return Future.value();
    return loadTransactions(payday: payday, offset: _periodOffset + 1);
  }

  /// Jump straight back to the current period.
  Future<void> resetToCurrentPeriod({required int payday}) =>
      loadTransactions(payday: payday, offset: 0);

  /// Load all transactions into the state (for history screen).
  Future<void> loadAllTransactions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allTransactions = await _repository.getAll();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch all transactions directly from repo (for export).
  Future<List<TransactionModel>> getAllTransactions() async {
    try {
      return await _repository.getAll();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Add a new transaction.
  Future<TransactionModel> addTransaction({
    required String type,
    required double amount,
    required String categoryId,
    required String accountId,
    required DateTime date,
    String? merchant,
    String? note,
    String? recurringId,
    String? goalId,
    String? debtId,
  }) async {
    try {
      final now = DateTime.now();
      final transaction = TransactionModel(
        id: _uuid.v4(),
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        merchant: merchant,
        date: date,
        note: note,
        recurringId: recurringId,
        goalId: goalId,
        debtId: debtId,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.insert(transaction);
      _applyInsert(transaction);

      notifyListeners();
      return transaction;
    } catch (e) {
      rethrow;
    }
  }

  /// Records a transfer as two linked legs — an expense on [fromAccountId]
  /// and an income on [toAccountId] — inserted atomically. Both are marked
  /// `isTransfer` so every income/expense aggregate (dashboard, budgets,
  /// analytics) ignores them; the account balances still move naturally
  /// since a plain income/expense sum is exactly what a balance is.
  Future<void> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Source and destination accounts must differ');
    }
    try {
      final transferId = _uuid.v4();
      final now = DateTime.now();
      final legs = [
        TransactionModel(
          id: _uuid.v4(),
          type: 'expense',
          amount: amount,
          categoryId: SeedData.transferCategoryId,
          accountId: fromAccountId,
          transferId: transferId,
          isTransfer: true,
          date: date,
          note: note,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionModel(
          id: _uuid.v4(),
          type: 'income',
          amount: amount,
          categoryId: SeedData.transferCategoryId,
          accountId: toAccountId,
          transferId: transferId,
          isTransfer: true,
          date: date,
          note: note,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await _repository.insertBatch(legs);
      for (final leg in legs) {
        _applyInsert(leg);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Shared by [addTransaction] and [addTransfer]: reflects a freshly
  /// inserted row into the in-memory lists/totals. Transfers must never
  /// move `_totalIncome`/`_totalExpense` — those mirror the SQL aggregates
  /// in [loadTransactions], which already exclude `isTransfer` rows.
  void _applyInsert(TransactionModel transaction) {
    if (_inPeriod(transaction.date)) {
      _transactions
        ..add(transaction)
        ..sort(_byDateDesc);
      if (!transaction.isTransfer) {
        if (transaction.isIncome) {
          _totalIncome += transaction.amount;
        } else {
          _totalExpense += transaction.amount;
        }
      }
    }

    _allTransactions
      ..add(transaction)
      ..sort(_byDateDesc);
  }

  /// Update an existing transaction.
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      final updated = transaction.copyWith(updatedAt: DateTime.now());
      await _repository.update(updated);

      final index = _transactions.indexWhere((t) => t.id == updated.id);
      final oldWasInPeriod = index != -1;
      final newIsInPeriod = _inPeriod(updated.date);

      // Only remove the OLD contribution if it was actually counted
      // (i.e. its date was in period), and only add the NEW contribution
      // if the (possibly changed) date is in period. Editing a date from
      // inside the period to outside it — or vice versa — must move the
      // totals by exactly one side of that swap, not both or neither.
      if (oldWasInPeriod) {
        final old = _transactions[index];
        if (!old.isTransfer) {
          if (old.isIncome) _totalIncome -= old.amount;
          if (old.isExpense) _totalExpense -= old.amount;
        }
      }
      if (newIsInPeriod && !updated.isTransfer) {
        if (updated.isIncome) _totalIncome += updated.amount;
        if (updated.isExpense) _totalExpense += updated.amount;
      }

      if (oldWasInPeriod && newIsInPeriod) {
        _transactions[index] = updated;
      } else if (oldWasInPeriod && !newIsInPeriod) {
        _transactions.removeAt(index);
      } else if (!oldWasInPeriod && newIsInPeriod) {
        _transactions.add(updated);
      }
      _transactions.sort(_byDateDesc);

      final allIndex = _allTransactions.indexWhere((t) => t.id == updated.id);
      if (allIndex != -1) {
        _allTransactions[allIndex] = updated;
        _allTransactions.sort(_byDateDesc);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a transaction. If it's one leg of a transfer, both legs are
  /// removed together — a transfer must never end up with only one side
  /// still posted.
  Future<void> deleteTransaction(String id) async {
    try {
      TransactionModel? target;
      for (final t in _allTransactions) {
        if (t.id == id) {
          target = t;
          break;
        }
      }
      target ??= await _repository.getById(id);
      if (target == null) return;

      final transferId = target.transferId;
      if (transferId != null) {
        await _repository.deleteTransferPair(transferId);
        for (final leg
            in _allTransactions.where((t) => t.transferId == transferId).toList()) {
          _removeFromMemory(leg);
        }
      } else {
        await _repository.delete(id);
        _removeFromMemory(target);
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void _removeFromMemory(TransactionModel transaction) {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      if (!transaction.isTransfer) {
        if (transaction.isIncome) _totalIncome -= transaction.amount;
        if (transaction.isExpense) _totalExpense -= transaction.amount;
      }
      _transactions.removeAt(index);
    }
    _allTransactions.removeWhere((t) => t.id == transaction.id);
  }

  /// Bulk-inserts transactions from a CSV/backup import. Unlike
  /// [addTransaction], this doesn't patch in-memory period totals
  /// incrementally — imported rows can land on arbitrary historical dates —
  /// so callers must reload (e.g. [loadTransactions]) afterward.
  Future<void> importTransactions(List<TransactionModel> transactions) async {
    if (transactions.isEmpty) return;
    await _repository.insertBatch(transactions);
  }

  /// Search transactions by note content.
  Future<List<TransactionModel>> searchTransactions(String query) async {
    try {
      if (query.isEmpty) return await _repository.getAll();
      return await _repository.search(query);
    } catch (e) {
      rethrow;
    }
  }

  /// Get grouped transactions by date for a list.
  Map<String, List<TransactionModel>> getGroupedTransactions(
    List<TransactionModel> items,
  ) {
    return AppDateUtils.groupByDate(items, (t) => t.date);
  }

  /// Get the sum spent in a specific category for the current period.
  Future<double> getCategorySpending(
    String categoryId,
    int payday,
  ) async {
    try {
      final period = AppDateUtils.getCurrentPeriod(payday);
      return await _repository.getCategorySumByDateRange(
        categoryId,
        period.start,
        period.end,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Merchants matching [query], most-used first — powers the entry
  /// form's autocomplete.
  Future<List<String>> suggestMerchants(String query) => _repository.getMerchantSuggestions(query);

  /// The category/account this merchant is most often paired with, or
  /// null if it's never been used before.
  Future<({String categoryId, String accountId})?> getMerchantDefaults(String merchant) =>
      _repository.getMerchantDefaults(merchant);
}
