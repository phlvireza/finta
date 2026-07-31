import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../core/utils/anomaly_detector.dart';
import '../core/utils/insight_rules.dart';
import '../core/utils/health_score.dart';
import '../core/utils/date_utils.dart';

/// Manages the on-device "intelligence layer" — unusual transactions,
/// rule-based spending insights, and the financial health score. All the
/// actual math lives in pure functions under core/utils/; this provider's
/// job is just fetching the data those functions need and holding the
/// result for the UI.
class InsightsProvider extends ChangeNotifier {
  final TransactionRepository _repository;

  InsightsProvider({TransactionRepository? repository})
      : _repository = repository ?? TransactionRepository();

  bool _isLoading = false;
  String? _error;
  List<TransactionModel> _unusualTransactions = [];
  List<SpendingInsightData> _spendingInsights = [];
  HealthScoreBreakdown? _healthScore;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<TransactionModel> get unusualTransactions => _unusualTransactions;
  List<SpendingInsightData> get spendingInsights => _spendingInsights;
  HealthScoreBreakdown? get healthScore => _healthScore;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// One-off check used at transaction entry time — deliberately doesn't
  /// touch or notify about provider state, since it's a per-keystroke-ish
  /// question ("is this amount unusual for this category?"), not something
  /// the Insights hub's loaded state should reflect.
  Future<({bool isAnomaly, double mean})?> checkAnomaly(String categoryId, double amount) async {
    final history = await _repository.getRecentAmountsForCategory(categoryId);
    final result = detectAnomaly(amount, history);
    if (result == null) return null;
    return (isAnomaly: result.isAnomaly, mean: result.mean);
  }

  /// Loads everything the Insights hub shows in one pass.
  Future<void> loadAll({
    required ({DateTime start, DateTime end}) currentPeriod,
    required ({DateTime start, DateTime end}) previousPeriod,
    required double currentIncome,
    required double currentExpense,
    required int payday,
    double? totalBudgeted,
    double? totalSpentAgainstBudgets,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadUnusualActivity(),
        _loadSpendingInsights(
          currentStart: currentPeriod.start,
          currentEnd: currentPeriod.end,
          previousStart: previousPeriod.start,
          previousEnd: previousPeriod.end,
        ),
        _loadHealthScore(
          income: currentIncome,
          expense: currentExpense,
          payday: payday,
          totalBudgeted: totalBudgeted,
          totalSpentAgainstBudgets: totalSpentAgainstBudgets,
        ),
      ]);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Scans the last [lookbackDays] of expenses and flags the ones that
  /// were unusually large for their category at the time — each checked
  /// against that category's own recent history, excluding itself.
  Future<void> _loadUnusualActivity({int lookbackDays = 30}) async {
    final now = DateTime.now();
    final recent = await _repository.getByDateRange(now.subtract(Duration(days: lookbackDays)), now);
    final candidates = recent.where((t) => t.isExpense && !t.isTransfer).toList();

    final flagged = <TransactionModel>[];
    for (final t in candidates) {
      final history = await _repository.getRecentAmountsForCategory(
        t.categoryId,
        excludeId: t.id,
      );
      final result = detectAnomaly(t.amount, history);
      if (result != null && result.isAnomaly) flagged.add(t);
    }

    flagged.sort((a, b) => b.date.compareTo(a.date));
    _unusualTransactions = flagged.take(10).toList();
  }

  Future<void> _loadSpendingInsights({
    required DateTime currentStart,
    required DateTime currentEnd,
    required DateTime previousStart,
    required DateTime previousEnd,
  }) async {
    final currentSums = await _repository.getCategorySums('expense', currentStart, currentEnd);
    final previousSums = await _repository.getCategorySums('expense', previousStart, previousEnd);
    final previousByCategory = {
      for (final row in previousSums) row['categoryId'] as String: (row['total'] as num).toDouble(),
    };

    final comparisons = currentSums.map((row) {
      final categoryId = row['categoryId'] as String;
      return CategoryComparisonInput(
        categoryId: categoryId,
        current: (row['total'] as num).toDouble(),
        previous: previousByCategory[categoryId] ?? 0,
      );
    }).toList();

    _spendingInsights = buildSpendingInsights(comparisons);
  }

  Future<void> _loadHealthScore({
    required double income,
    required double expense,
    required int payday,
    double? totalBudgeted,
    double? totalSpentAgainstBudgets,
  }) async {
    final savingsRate = income > 0 ? (income - expense) / income : 0.0;
    final budgetAdherenceRatio = (totalBudgeted != null && totalBudgeted > 0)
        ? (totalSpentAgainstBudgets ?? 0) / totalBudgeted
        : null;

    final recentIncomes = await _recentPeriodIncomes(payday);
    final incomeCoV = coefficientOfVariation(recentIncomes);

    _healthScore = calculateHealthScore(
      savingsRate: savingsRate,
      budgetAdherenceRatio: budgetAdherenceRatio,
      incomeCoefficientOfVariation: incomeCoV,
    );
  }

  /// Income totals for the current period plus the [count] - 1 before it —
  /// the income-stability score's raw data.
  Future<List<double>> _recentPeriodIncomes(int payday, {int count = 6}) async {
    final incomes = <double>[];
    var period = AppDateUtils.getCurrentPeriod(payday);
    for (var i = 0; i < count; i++) {
      final total = await _repository.getSumByTypeAndDateRange('income', period.start, period.end);
      incomes.add(total);
      period = AppDateUtils.getPreviousPeriod(period);
    }
    return incomes;
  }
}
