import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';

/// Full-screen yearly summary report with a line chart and high-level stats.
class YearlyReportScreen extends StatefulWidget {
  const YearlyReportScreen({super.key});

  @override
  State<YearlyReportScreen> createState() => _YearlyReportScreenState();
}

class _YearlyReportScreenState extends State<YearlyReportScreen> {
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    // Load available years, then load data for the first available year (usually current)
    context.read<AnalyticsProvider>().loadAvailableYears().then((_) {
      final years = context.read<AnalyticsProvider>().availableYears;
      if (years.isNotEmpty) {
        setState(() => _selectedYear = years.first);
        _loadData();
      }
    });
  }

  void _loadData() {
    context.read<AnalyticsProvider>().loadYearlyData(_selectedYear);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = context.watch<AnalyticsProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.yearlyReport),
      ),
      body: analytics.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              children: [
                // Year selector
                if (analytics.availableYears.length > 1)
                  Center(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      items: analytics.availableYears.map((y) {
                        return DropdownMenuItem(value: y, child: Text('$y'));
                      }).toList(),
                      onChanged: (y) {
                        if (y != null) {
                          setState(() => _selectedYear = y);
                          _loadData();
                        }
                      },
                    ),
                  )
                else
                  Center(
                    child: Text(
                      '$_selectedYear',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                const SizedBox(height: AppConstants.spacingXxxl),

                // Chart
                _YearlyTrendChart(data: analytics.monthlyData),
                const SizedBox(height: AppConstants.spacingXxxl),

                // Summary Stats
                _YearlySummaryStats(
                  data: analytics.monthlyData,
                  symbol: settings.currencySymbol,
                  useDecimals: settings.currencyUseDecimals,
                ),
              ],
            ),
    );
  }
}

class _YearlyTrendChart extends StatelessWidget {
  final List<MonthlyData> data;

  const _YearlyTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final incomeColor = isDark ? AppColors.darkIncome : AppColors.lightIncome;
    final expenseColor = isDark ? AppColors.darkExpense : AppColors.lightExpense;

    if (data.isEmpty) return const SizedBox(height: 200);

    double maxVal = 0;
    for (final d in data) {
      if (d.income > maxVal) maxVal = d.income;
      if (d.expense > maxVal) maxVal = d.expense;
    }
    if (maxVal == 0) maxVal = 100; // default scale

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxVal * 1.1,
          lineBarsData: [
            // Income Line
            LineChartBarData(
              spots: data.map((d) => FlSpot(d.month.toDouble(), d.income)).toList(),
              isCurved: true,
              color: incomeColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: incomeColor.withValues(alpha: 0.1),
              ),
            ),
            // Expense Line
            LineChartBarData(
              spots: data.map((d) => FlSpot(d.month.toDouble(), d.expense)).toList(),
              isCurved: true,
              color: expenseColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: expenseColor.withValues(alpha: 0.1),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  final month = value.toInt();
                  if (month >= 1 && month <= 12) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        AppDateUtils.monthShort(month),
                        style: theme.textTheme.labelSmall,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _YearlySummaryStats extends StatelessWidget {
  final List<MonthlyData> data;
  final String symbol;
  final bool useDecimals;

  const _YearlySummaryStats({
    required this.data,
    required this.symbol,
    required this.useDecimals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    double totalIncome = 0;
    double totalExpense = 0;
    for (final d in data) {
      totalIncome += d.income;
      totalExpense += d.expense;
    }
    final net = totalIncome - totalExpense;

    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.summary, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppConstants.spacingMd),
        Container(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            children: [
              _StatRow(
                label: loc.totalIncome,
                amount: totalIncome,
                color: isDark ? AppColors.darkIncome : AppColors.lightIncome,
                symbol: symbol,
                useDecimals: useDecimals,
              ),
              const Divider(height: AppConstants.spacingXxl),
              _StatRow(
                label: loc.totalExpense,
                amount: totalExpense,
                color: isDark ? AppColors.darkExpense : AppColors.lightExpense,
                symbol: symbol,
                useDecimals: useDecimals,
              ),
              const Divider(height: AppConstants.spacingXxl),
              _StatRow(
                label: loc.netSavings,
                amount: net,
                color: theme.textTheme.bodyLarge!.color!,
                symbol: symbol,
                useDecimals: useDecimals,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String symbol;
  final bool useDecimals;

  const _StatRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.symbol,
    required this.useDecimals,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Text(
          NumberUtils.formatCurrency(
            amount,
            symbol: symbol,
            useDecimals: useDecimals,
          ),
          style: AppTypography.amountStyle(
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
