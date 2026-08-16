import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../models/category_model.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/trend_utils.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/status_pill.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/category_display.dart';

/// Full-screen trends report: rolling 12-month cashflow and a per-category
/// spend trend with a vs-average callout — the long-range views the
/// dashboard's single-period cards can't show.
///
/// Two things deliberately do *not* live here. Top merchants was pinned to a
/// hardcoded three-month window while this screen has no period selector, so
/// it sits on the analytics screen and follows the period the user actually
/// picked. The spending heatmap moved to the dashboard, where it is scoped to
/// the pay period instead of paging calendar months.
class TrendsReportScreen extends StatefulWidget {
  const TrendsReportScreen({super.key});

  @override
  State<TrendsReportScreen> createState() => _TrendsReportScreenState();
}

class _TrendsReportScreenState extends State<TrendsReportScreen> {
  String? _trendCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final analytics = context.read<AnalyticsProvider>();

    await analytics.loadCashflow();

    if (!mounted) return;
    final categories = context.read<CategoryProvider>().expenseCategories;
    if (categories.isNotEmpty) {
      setState(() => _trendCategoryId = categories.first.id);
      await analytics.loadCategoryTrend(categories.first.id);
    }
  }

  Future<void> _onTrendCategoryChanged(String? categoryId) async {
    if (categoryId == null) return;
    setState(() => _trendCategoryId = categoryId);
    await context.read<AnalyticsProvider>().loadCategoryTrend(categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final analytics = context.watch<AnalyticsProvider>();
    final settings = context.watch<SettingsProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(loc.trends)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          AppConstants.spacingMd,
          AppConstants.spacingLg,
          AppConstants.fabClearance,
        ),
        children: [
          SectionCard(
            title: loc.cashflow,
            child: _CashflowChart(
              data: analytics.cashflow,
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SectionCard(
            title: loc.categoryTrend,
            child: _CategoryTrendSection(
              categories: categoryProvider.expenseCategories,
              selectedCategoryId: _trendCategoryId,
              onChanged: _onTrendCategoryChanged,
              data: analytics.categoryTrend,
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowChart extends StatelessWidget {
  final List<CashflowMonth> data;
  final String symbol;
  final bool useDecimals;

  const _CashflowChart({required this.data, required this.symbol, required this.useDecimals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    if (data.isEmpty || data.every((d) => d.income == 0 && d.expense == 0)) {
      return EmptyState(icon: Icons.bar_chart_outlined, title: loc.noDataForThisPeriod, subtitle: '');
    }

    final isDark = theme.brightness == Brightness.dark;
    final incomeColor = isDark ? AppColors.darkIncome : AppColors.lightIncome;
    final expenseColor = isDark ? AppColors.darkExpense : AppColors.lightExpense;

    double maxVal = 0;
    for (final d in data) {
      if (d.income > maxVal) maxVal = d.income;
      if (d.expense > maxVal) maxVal = d.expense;
    }
    if (maxVal == 0) maxVal = 100;

    final totalNet = data.fold(0.0, (sum, d) => sum + d.net);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.15,
              barGroups: [
                for (var i = 0; i < data.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(toY: data[i].income, color: incomeColor, width: 6),
                      BarChartRodData(toY: data[i].expense, color: expenseColor, width: 6),
                    ],
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
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          AppDateUtils.monthShort(data[index].monthStart.month),
                          style: theme.textTheme.labelSmall,
                        ),
                      );
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
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    NumberUtils.formatCurrency(rod.toY, symbol: symbol, useDecimals: useDecimals),
                    TextStyle(color: theme.colorScheme.onInverseSurface),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        StatusPill(
          label: loc.netCashflowOverMonths(
            data.length,
            NumberUtils.formatCurrency(totalNet, symbol: symbol, useDecimals: useDecimals),
          ),
          color: totalNet >= 0 ? incomeColor : expenseColor,
        ),
      ],
    );
  }
}

class _CategoryTrendSection extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;
  final List<MonthlyCategoryTotal> data;
  final String symbol;
  final bool useDecimals;

  const _CategoryTrendSection({
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
    required this.data,
    required this.symbol,
    required this.useDecimals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    if (categories.isEmpty) {
      return EmptyState(icon: Icons.show_chart, title: loc.noDataForThisPeriod, subtitle: '');
    }

    final callout = trendVsAverage(data.map((d) => d.total).toList());

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedCategoryId,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final c in categories)
              DropdownMenuItem(value: c.id, child: Text(categoryDisplayName(c, loc))),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: AppConstants.spacingMd),
        if (data.isEmpty || data.every((d) => d.total == 0))
          EmptyState(icon: Icons.show_chart, title: loc.noDataForThisPeriod, subtitle: '')
        else ...[
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].total)],
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.1)),
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
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            AppDateUtils.monthShort(data[index].monthStart.month),
                            style: theme.textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map((s) => LineTooltipItem(
                              NumberUtils.formatCurrency(s.y, symbol: symbol, useDecimals: useDecimals),
                              TextStyle(color: theme.colorScheme.onInverseSurface),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          if (callout != null) ...[
            const SizedBox(height: AppConstants.spacingMd),
            StatusPill(
              label: callout.isAbove
                  ? loc.categoryAboveAverage(callout.percent.toStringAsFixed(0), data.length - 1)
                  : loc.categoryBelowAverage(callout.percent.toStringAsFixed(0), data.length - 1),
              color: callout.isAbove ? AppColors.warning : theme.colorScheme.primary,
            ),
          ],
        ],
      ],
    );
  }
}
