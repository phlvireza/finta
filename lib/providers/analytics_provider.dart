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

/// One month in a rolling (not calendar-year-bound) trend series —
/// [monthStart] is the 1st of that month, so a 12-month window spanning a
/// year boundary sorts and labels correctly.
class CashflowMonth {
  final DateTime monthStart;
  final double income;
  final double expense;

  const CashflowMonth({required this.monthStart, required this.income, required this.expense});

  double get net => income - expense;
}

class MerchantAnalytics {
  final String merchant;
  final double total;
  final int count;

  const MerchantAnalytics({required this.merchant, required this.total, required this.count});
}

/// One month's total for a single category — the category trend chart's
/// data point.
class MonthlyCategoryTotal {
  final DateTime monthStart;
  final double total;

  const MonthlyCategoryTotal({required this.monthStart, required this.total});
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
  List<CashflowMonth> _cashflow = [];
  List<MonthlyCategoryTotal> _categoryTrend = [];
  Map<String, double> _dailyExpenses = {};
  List<MerchantAnalytics> _topMerchants = [];
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
  List<CashflowMonth> get cashflow => _cashflow;
  List<MonthlyCategoryTotal> get categoryTrend => _categoryTrend;
  Map<String, double> get dailyExpenses => _dailyExpenses;
  List<MerchantAnalytics> get topMerchants => _topMerchants;
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
  ///
  /// [comparedTo] additionally fills the `previousTotal*` getters, so a
  /// caller that needs a "versus last period" line doesn't have to reach
  /// past this provider into the repository for it.
  Future<void> loadAnalytics({
    required DateTime start,
    required DateTime end,
    ({DateTime start, DateTime end})? comparedTo,
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

      // Always reassigned, never left over from an earlier range — a stale
      // comparison is worse than no comparison.
      _previousTotalExpense = comparedTo == null
          ? 0
          : await _repository.getSumByTypeAndDateRange('expense', comparedTo.start, comparedTo.end);
      _previousTotalIncome = comparedTo == null
          ? 0
          : await _repository.getSumByTypeAndDateRange('income', comparedTo.start, comparedTo.end);
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

    await loadAnalytics(start: current.start, end: current.end, comparedTo: previous);
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

  /// Rolling last [months] calendar months of income/expense, ending with
  /// the current month — unlike [loadYearlyData], never bound to a single
  /// calendar year, so "last 12 months" always means the last 12 months.
  Future<void> loadCashflow({int months = 12}) async {
    try {
      final now = DateTime.now();
      final end = DateTime(now.year, now.month + 1, 0);
      final start = DateTime(now.year, now.month - months + 1, 1);
      final rows = await _repository.getMonthlySumsInRange(start, end);

      final byMonth = <String, ({double income, double expense})>{};
      for (var i = 0; i < months; i++) {
        final m = DateTime(start.year, start.month + i, 1);
        byMonth[_ymKey(m)] = (income: 0, expense: 0);
      }
      for (final row in rows) {
        final key = row['ym'] as String;
        final type = row['type'] as String;
        final total = (row['total'] as num).toDouble();
        final existing = byMonth[key];
        if (existing == null) continue;
        byMonth[key] = type == 'income'
            ? (income: total, expense: existing.expense)
            : (income: existing.income, expense: total);
      }

      _cashflow = byMonth.entries.map((e) {
        final parts = e.key.split('-');
        return CashflowMonth(
          monthStart: DateTime(int.parse(parts[0]), int.parse(parts[1]), 1),
          income: e.value.income,
          expense: e.value.expense,
        );
      }).toList()
        ..sort((a, b) => a.monthStart.compareTo(b.monthStart));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// A single category's spend over the last [months] calendar months.
  Future<void> loadCategoryTrend(String categoryId, {int months = 6}) async {
    try {
      final now = DateTime.now();
      final end = DateTime(now.year, now.month + 1, 0);
      final start = DateTime(now.year, now.month - months + 1, 1);
      final rows = await _repository.getCategoryMonthlySums(categoryId, start, end);

      final byMonth = <String, double>{};
      for (var i = 0; i < months; i++) {
        final m = DateTime(start.year, start.month + i, 1);
        byMonth[_ymKey(m)] = 0;
      }
      for (final row in rows) {
        final key = row['ym'] as String;
        if (!byMonth.containsKey(key)) continue;
        byMonth[key] = (row['total'] as num).toDouble();
      }

      _categoryTrend = byMonth.entries.map((e) {
        final parts = e.key.split('-');
        return MonthlyCategoryTotal(
          monthStart: DateTime(int.parse(parts[0]), int.parse(parts[1]), 1),
          total: e.value,
        );
      }).toList()
        ..sort((a, b) => a.monthStart.compareTo(b.monthStart));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Daily expense totals across [start]..[end], keyed by ISO date string —
  /// powers the spending heatmap calendar, reloaded whenever it's paged to
  /// a different month.
  Future<void> loadDailyExpenses(DateTime start, DateTime end) async {
    try {
      final rows = await _repository.getDailyExpenseSums(start, end);
      _dailyExpenses = {
        for (final row in rows) row['date'] as String: (row['total'] as num).toDouble(),
      };
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// The highest-spend merchants of [type] across [start]..[end].
  Future<void> loadTopMerchants(String type, DateTime start, DateTime end, {int limit = 10}) async {
    try {
      final rows = await _repository.getTopMerchants(type, start, end, limit: limit);
      _topMerchants = rows
          .map((row) => MerchantAnalytics(
                merchant: row['merchant'] as String,
                total: (row['total'] as num).toDouble(),
                count: row['cnt'] as int,
              ))
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  static String _ymKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
}
