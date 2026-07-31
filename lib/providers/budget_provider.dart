import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import '../core/services/budget_rollover_service.dart';
import '../core/utils/date_utils.dart';
import '../core/constants/app_constants.dart';

enum BudgetAlertType { exceeded, warning }

class BudgetAlertResult {
  final BudgetAlertType type;
  final String percentage;

  BudgetAlertResult({required this.type, this.percentage = ''});
}

/// Budget spending data for a single budget (whatever its scope).
class BudgetStatus {
  final BudgetModel budget;
  final double spent;
  final double rolloverAmount;

  const BudgetStatus({required this.budget, required this.spent, this.rolloverAmount = 0});

  /// The limit that actually applies to this period, once rollover from
  /// prior periods is folded in — this is what [ratio]/[remaining] measure
  /// against, not the budget's flat [BudgetModel.amount].
  double get effectiveAmount => budget.amount + rolloverAmount;

  double get ratio => effectiveAmount > 0 ? spent / effectiveAmount : 0;
  double get remaining => (effectiveAmount - spent).clamp(0, double.infinity);
  bool get isWarning =>
      ratio >= AppConstants.budgetWarningThreshold && ratio < AppConstants.budgetExceededThreshold;
  bool get isExceeded => ratio >= AppConstants.budgetExceededThreshold;
  bool get isNormal => ratio < AppConstants.budgetWarningThreshold;
}

/// Manages budget state — CRUD + spending calculations.
class BudgetProvider extends ChangeNotifier {
  final BudgetRepository _repository;
  final TransactionRepository _transactionRepo;
  final BudgetRolloverService _rolloverService;
  static const _uuid = Uuid();

  BudgetProvider({
    BudgetRepository? repository,
    TransactionRepository? transactionRepo,
    BudgetRolloverService? rolloverService,
  })  : _repository = repository ?? BudgetRepository(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _rolloverService = rolloverService ?? BudgetRolloverService();

  List<BudgetModel> _budgets = [];
  Map<String, BudgetStatus> _budgetStatuses = {}; // keyed by budget.id
  bool _isLoading = false;
  String? _error;

  List<BudgetModel> get budgets => _budgets;
  Map<String, BudgetStatus> get budgetStatuses => _budgetStatuses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<BudgetModel> get activeBudgets =>
      _budgets.where((b) => b.isActive).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Load budgets and calculate spending for each.
  Future<void> loadBudgets({required int payday}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _budgets = await _repository.getAll();
      await _calculateStatuses(payday);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recalculate every active budget's spending status for its own
  /// current period (periods can differ per budget: weekly/monthly/
  /// quarterly/yearly).
  Future<void> _calculateStatuses(int payday) async {
    final statuses = <String, BudgetStatus>{};

    for (final budget in _budgets.where((b) => b.isActive)) {
      final period = AppDateUtils.getCurrentPeriodFor(budget.period, payday);
      final spent = await _spentFor(budget, period.start, period.end);
      final rollover = await _rolloverService.getCarriedAmount(budget, payday: payday);
      statuses[budget.id] = BudgetStatus(budget: budget, spent: spent, rolloverAmount: rollover);
    }

    _budgetStatuses = statuses;
  }

  Future<double> _spentFor(BudgetModel budget, DateTime start, DateTime end) {
    if (budget.scope == 'overall') {
      return _transactionRepo.getSumByTypeAndDateRange('expense', start, end);
    }
    return _transactionRepo.getCategoriesSumByDateRange(budget.categoryIds, start, end);
  }

  /// The status of whichever active budget covers [categoryId] — a
  /// category-scoped budget for it directly, or a group budget that
  /// includes it. A category can only be covered by one budget in
  /// practice (the form prevents double-assignment), so the first match
  /// is authoritative.
  BudgetStatus? getStatusForCategory(String categoryId) {
    for (final status in _budgetStatuses.values) {
      if (status.budget.scope != 'overall' && status.budget.categoryIds.contains(categoryId)) {
        return status;
      }
    }
    return null;
  }

  /// Get the first N budget statuses (ordered by creation date).
  List<BudgetStatus> getTopStatuses(int count) {
    final statuses = _budgets
        .where((b) => b.isActive)
        .map((b) => _budgetStatuses[b.id])
        .where((s) => s != null)
        .cast<BudgetStatus>()
        .toList();
    return statuses.take(count).toList();
  }

  /// Check if adding an expense would cross a budget threshold — checks
  /// whichever budget (category or group) covers [categoryId], plus any
  /// active overall budget.
  BudgetAlertResult? checkBudgetAlert(String categoryId, double additionalAmount, int payday) {
    final status = getStatusForCategory(categoryId) ??
        _budgetStatuses.values.where((s) => s.budget.scope == 'overall').firstOrNull;
    if (status == null) return null;

    final newSpent = status.spent + additionalAmount;
    final newRatio = status.effectiveAmount > 0 ? newSpent / status.effectiveAmount : 0;

    // Use amount comparison to avoid floating point precision issues near 1.0
    if (newSpent > status.effectiveAmount && status.spent <= status.effectiveAmount) {
      return BudgetAlertResult(type: BudgetAlertType.exceeded);
    }

    if (newRatio >= AppConstants.budgetWarningThreshold &&
        status.ratio < AppConstants.budgetWarningThreshold) {
      final pct = (newRatio * 100).toStringAsFixed(0);
      return BudgetAlertResult(type: BudgetAlertType.warning, percentage: pct);
    }
    return null;
  }

  Future<void> addBudget({
    String? name,
    required double amount,
    String period = 'monthly',
    String rolloverMode = 'none',
    required String scope,
    required List<String> categoryIds,
    required int payday,
  }) async {
    try {
      final now = DateTime.now();
      final budget = BudgetModel(
        id: _uuid.v4(),
        name: name,
        amount: amount,
        period: period,
        rolloverMode: rolloverMode,
        scope: scope,
        categoryIds: scope == 'overall' ? const [] : categoryIds,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.insert(budget);
      _budgets.add(budget);

      final periodRange = AppDateUtils.getCurrentPeriodFor(budget.period, payday);
      final spent = await _spentFor(budget, periodRange.start, periodRange.end);
      final rollover = await _rolloverService.getCarriedAmount(budget, payday: payday);
      _budgetStatuses[budget.id] = BudgetStatus(budget: budget, spent: spent, rolloverAmount: rollover);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateBudget(BudgetModel budget, {required int payday}) async {
    try {
      final updated = budget.copyWith(updatedAt: DateTime.now());
      await _repository.update(updated);
      final index = _budgets.indexWhere((b) => b.id == updated.id);
      if (index != -1) {
        _budgets[index] = updated;

        final periodRange = AppDateUtils.getCurrentPeriodFor(updated.period, payday);
        final spent = await _spentFor(updated, periodRange.start, periodRange.end);
        final rollover = await _rolloverService.getCarriedAmount(updated, payday: payday);
        _budgetStatuses[updated.id] = BudgetStatus(budget: updated, spent: spent, rolloverAmount: rollover);

        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteBudget(String id) async {
    try {
      await _repository.delete(id);

      final index = _budgets.indexWhere((b) => b.id == id);
      if (index != -1) {
        _budgetStatuses.remove(id);
        _budgets.removeAt(index);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
