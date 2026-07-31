import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import '../core/utils/date_utils.dart';
import '../core/constants/app_constants.dart';

enum BudgetAlertType { exceeded, warning }

class BudgetAlertResult {
  final BudgetAlertType type;
  final String percentage;

  BudgetAlertResult({required this.type, this.percentage = ''});
}

/// Budget spending data for a single category.
class BudgetStatus {
  final BudgetModel budget;
  final double spent;

  const BudgetStatus({required this.budget, required this.spent});

  double get ratio => budget.amount > 0 ? spent / budget.amount : 0;
  double get remaining => (budget.amount - spent).clamp(0, double.infinity);
  bool get isWarning => ratio >= AppConstants.budgetWarningThreshold && ratio < AppConstants.budgetExceededThreshold;
  bool get isExceeded => ratio >= AppConstants.budgetExceededThreshold;
  bool get isNormal => ratio < AppConstants.budgetWarningThreshold;
}

/// Manages budget state — CRUD + spending calculations.
class BudgetProvider extends ChangeNotifier {
  final BudgetRepository _repository;
  final TransactionRepository _transactionRepo;
  static const _uuid = Uuid();

  BudgetProvider({
    BudgetRepository? repository,
    TransactionRepository? transactionRepo,
  })  : _repository = repository ?? BudgetRepository(),
        _transactionRepo = transactionRepo ?? TransactionRepository();

  List<BudgetModel> _budgets = [];
  Map<String, BudgetStatus> _budgetStatuses = {};
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

  /// Recalculate budget spending statuses for the current period.
  Future<void> _calculateStatuses(int payday) async {
    final period = AppDateUtils.getCurrentPeriod(payday);
    final statuses = <String, BudgetStatus>{};

    for (final budget in _budgets.where((b) => b.isActive)) {
      final spent = await _transactionRepo.getCategorySumByDateRange(
        budget.categoryId,
        period.start,
        period.end,
      );
      statuses[budget.categoryId] = BudgetStatus(
        budget: budget,
        spent: spent,
      );
    }

    _budgetStatuses = statuses;
  }

  /// Get the budget status for a specific category (if any).
  BudgetStatus? getStatusForCategory(String categoryId) {
    return _budgetStatuses[categoryId];
  }

  /// Get the first N budget statuses (ordered by creation date).
  List<BudgetStatus> getTopStatuses(int count) {
    final statuses = _budgets
        .where((b) => b.isActive)
        .map((b) => _budgetStatuses[b.categoryId])
        .where((s) => s != null)
        .cast<BudgetStatus>()
        .toList();
    return statuses.take(count).toList();
  }

  /// Check if adding an expense would cross a budget threshold.
  /// Returns a BudgetAlertResult if so, or null.
  BudgetAlertResult? checkBudgetAlert(String categoryId, double additionalAmount, int payday) {
    final status = _budgetStatuses[categoryId];
    if (status == null) return null;

    final newSpent = status.spent + additionalAmount;
    final newRatio = newSpent / status.budget.amount;

    // Use amount comparison to avoid floating point precision issues near 1.0
    if (newSpent > status.budget.amount && status.spent <= status.budget.amount) {
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
    required String categoryId,
    required double amount,
    required int payday,
  }) async {
    try {
      final now = DateTime.now();
      final budget = BudgetModel(
        id: _uuid.v4(),
        categoryId: categoryId,
        amount: amount,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.insert(budget);
      _budgets.add(budget);

      // Initialize status for the new budget
      final period = AppDateUtils.getCurrentPeriod(payday);
      final spent = await _transactionRepo.getCategorySumByDateRange(
        budget.categoryId,
        period.start,
        period.end,
      );
      _budgetStatuses[budget.categoryId] = BudgetStatus(
        budget: budget,
        spent: spent,
      );

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateBudget(BudgetModel budget) async {
    try {
      final updated = budget.copyWith(updatedAt: DateTime.now());
      await _repository.update(updated);
      final index = _budgets.indexWhere((b) => b.id == updated.id);
      if (index != -1) {
        _budgets[index] = updated;

        // Update the status object with the new budget reference
        final oldStatus = _budgetStatuses[updated.categoryId];
        if (oldStatus != null) {
          _budgetStatuses[updated.categoryId] = BudgetStatus(
            budget: updated,
            spent: oldStatus.spent,
          );
        }

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
        final budget = _budgets[index];
        _budgetStatuses.remove(budget.categoryId);
        _budgets.removeAt(index);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }
}
