import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../core/utils/date_utils.dart';
import '../core/constants/app_constants.dart';

/// Manages transaction state — CRUD, balance calculations, filtered lists.
class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repository;
  static const _uuid = Uuid();

  TransactionProvider({TransactionRepository? repository})
      : _repository = repository ?? TransactionRepository();

  List<TransactionModel> _transactions = [];
  List<TransactionModel> _recentTransactions = [];
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
  List<TransactionModel> get recentTransactions => _recentTransactions;
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
      _recentTransactions = await _repository.getRecent(AppConstants.recentTransactionCount);

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
    required DateTime date,
    String? note,
    String? recurringId,
  }) async {
    try {
      final now = DateTime.now();
      final transaction = TransactionModel(
        id: _uuid.v4(),
        type: type,
        amount: amount,
        categoryId: categoryId,
        date: date,
        note: note,
        recurringId: recurringId,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.insert(transaction);

      // Only reflect the new entry in the period-scoped list/totals if its
      // date actually falls in the currently loaded period — a backdated
      // or forward-dated transaction must not move numbers for a period
      // it doesn't belong to.
      if (_inPeriod(transaction.date)) {
        _transactions
          ..add(transaction)
          ..sort(_byDateDesc);
        if (transaction.isIncome) {
          _totalIncome += amount;
        } else {
          _totalExpense += amount;
        }
      }

      _allTransactions
        ..add(transaction)
        ..sort(_byDateDesc);
      _recentTransactions = await _repository.getRecent(AppConstants.recentTransactionCount);

      notifyListeners();
      return transaction;
    } catch (e) {
      rethrow;
    }
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
        if (old.isIncome) _totalIncome -= old.amount;
        if (old.isExpense) _totalExpense -= old.amount;
      }
      if (newIsInPeriod) {
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

      _recentTransactions = await _repository.getRecent(AppConstants.recentTransactionCount);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a transaction.
  Future<void> deleteTransaction(String id) async {
    try {
      await _repository.delete(id);

      final index = _transactions.indexWhere((t) => t.id == id);
      if (index != -1) {
        final transaction = _transactions[index];
        if (transaction.isIncome) _totalIncome -= transaction.amount;
        if (transaction.isExpense) _totalExpense -= transaction.amount;
        _transactions.removeAt(index);
      }
      
      _allTransactions.removeWhere((t) => t.id == id);

      _recentTransactions = await _repository.getRecent(AppConstants.recentTransactionCount);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
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
}
