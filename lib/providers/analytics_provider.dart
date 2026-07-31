import 'package:flutter/material.dart';
import '../repositories/transaction_repository.dart';
import '../core/utils/date_utils.dart';

enum AnalyticsPeriod { weekly, biweekly, monthly, yearly }

/// Holds aggregated analytics data for charts and reports.
class CategoryAnalytics {
  final String categoryId;
  final double total;
  final double percentage;

  const CategoryAnalytics({
    required this.categoryId,
    required this.total,
    required this.percentage,
  });
}

class MonthlyData {
  final int month;
  final double income;
  final double expense;

  const MonthlyData({
    required this.month,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

/// Manages analytics state — category breakdowns, period filtering, yearly stats.
class AnalyticsProvider extends ChangeNotifier {
  final TransactionRepository _repository;

  AnalyticsProvider({TransactionRepository? repository})
      : _repository = repository ?? TransactionRepository();

  List<CategoryAnalytics> _expenseBreakdown = [];
  List<CategoryAnalytics> _incomeBreakdown = [];
  List<MonthlyData> _monthlyData = [];
  List<int> _availableYears = [];
  double _totalExpense = 0;
  double _totalIncome = 0;
  double _previousTotalExpense = 0;
  double _previousTotalIncome = 0;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.monthly;
  bool _isLoading = false;
  String? _error;

  List<CategoryAnalytics> get expenseBreakdown => _expenseBreakdown;
  List<CategoryAnalytics> get incomeBreakdown => _incomeBreakdown;
  List<MonthlyData> get monthlyData => _monthlyData;
  List<int> get availableYears => _availableYears;
  double get totalExpense => _totalExpense;
  double get totalIncome => _totalIncome;
  double get previousTotalExpense => _previousTotalExpense;
  double get previousTotalIncome => _previousTotalIncome;
  AnalyticsPeriod get selectedPeriod => _selectedPeriod;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Load category breakdowns for a given period.
  Future<void> loadAnalytics({
    required DateTime start,
    required DateTime end,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Expense breakdown
      final expenseSums = await _repository.getCategorySums('expense', start, end);
      _totalExpense = await _repository.getSumByTypeAndDateRange('expense', start, end);
      _expenseBreakdown = expenseSums.map((m) {
        final total = (m['total'] as num).toDouble();
        return CategoryAnalytics(
          categoryId: m['categoryId'] as String,
          total: total,
          percentage: _totalExpense > 0 ? total / _totalExpense : 0,
        );
      }).toList();

      // Income breakdown
      final incomeSums = await _repository.getCategorySums('income', start, end);
      _totalIncome = await _repository.getSumByTypeAndDateRange('income', start, end);
      _incomeBreakdown = incomeSums.map((m) {
        final total = (m['total'] as num).toDouble();
        return CategoryAnalytics(
          categoryId: m['categoryId'] as String,
          total: total,
          percentage: _totalIncome > 0 ? total / _totalIncome : 0,
        );
      }).toList();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load analytics for the current period based on user selection.
  Future<void> loadForCurrentPeriod(int payday) async {
    ({DateTime start, DateTime end}) current;
    
    switch (_selectedPeriod) {
      case AnalyticsPeriod.weekly:
        current = AppDateUtils.getWeeklyPeriod();
        break;
      case AnalyticsPeriod.biweekly:
        current = AppDateUtils.getBiweeklyPeriod();
        break;
      case AnalyticsPeriod.monthly:
      case AnalyticsPeriod.yearly:
        current = AppDateUtils.getCurrentPeriod(payday);
        break;
    }

    final previous = AppDateUtils.getPreviousPeriod(current);
    
    await loadAnalytics(start: current.start, end: current.end);
    
    // Fetch previous period totals for comparison
    _previousTotalExpense = await _repository.getSumByTypeAndDateRange('expense', previous.start, previous.end);
    _previousTotalIncome = await _repository.getSumByTypeAndDateRange('income', previous.start, previous.end);
    notifyListeners();
  }

  void setPeriodFilter(AnalyticsPeriod period, int payday) {
    if (_selectedPeriod == period) return;
    _selectedPeriod = period;
    
    if (period == AnalyticsPeriod.yearly) {
      loadYearlyData(DateTime.now().year);
    } else {
      loadForCurrentPeriod(payday);
    }
  }

  /// Load monthly data for a specific year (yearly report).
  Future<void> loadYearlyData(int year) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final monthlySums = await _repository.getMonthlySums(year);
      final monthMap = <int, MonthlyData>{};

      // Initialize all months
      for (var m = 1; m <= 12; m++) {
        monthMap[m] = MonthlyData(month: m, income: 0, expense: 0);
      }

      // Fill in actual data
      for (final row in monthlySums) {
        final month = int.parse(row['month'] as String);
        final type = row['type'] as String;
        final total = (row['total'] as num).toDouble();

        final existing = monthMap[month]!;
        monthMap[month] = MonthlyData(
          month: month,
          income: type == 'income' ? total : existing.income,
          expense: type == 'expense' ? total : existing.expense,
        );
      }

      _monthlyData = monthMap.values.toList()..sort((a, b) => a.month.compareTo(b.month));
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load the list of years that have transaction data.
  Future<void> loadAvailableYears() async {
    try {
      _availableYears = await _repository.getDistinctYears();
      if (_availableYears.isEmpty) {
        _availableYears = [DateTime.now().year];
      }
      notifyListeners();
    } catch (e) {
      // Non-critical, just keep default
      _availableYears = [DateTime.now().year];
      notifyListeners();
    }
  }
}
