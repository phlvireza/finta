import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/category_model.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../transactions/widgets/transaction_tile.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/trend_utils.dart';
import '../../../widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';

/// Full-screen trends report: rolling 12-month cashflow, a per-category
/// spend trend with a vs-average callout, and a spending intensity heatmap —
/// everything the dashboard's burn rate and budget pace don't already cover.
///
/// Top merchants deliberately does *not* live here. It was pinned to a
/// hardcoded three-month window while this screen has no period selector,
/// so it now sits on the analytics screen and follows the period the user
/// actually picked.
class TrendsReportScreen extends StatefulWidget {
  const TrendsReportScreen({super.key});

  @override
  State<TrendsReportScreen> createState() => _TrendsReportScreenState();
}

class _TrendsReportScreenState extends State<TrendsReportScreen> {
  String? _trendCategoryId;
  DateTime _heatmapMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final analytics = context.read<AnalyticsProvider>();

    await Future.wait([
      analytics.loadCashflow(),
      analytics.loadDailyExpenses(_heatmapMonth, DateTime(_heatmapMonth.year, _heatmapMonth.month + 1, 0)),
    ]);

    if (!mounted) return;
    final categories = context.read<CategoryProvider>().expenseCategories;
    if (categories.isNotEmpty) {
      setState(() => _trendCategoryId = categories.first.id);
      await analytics.loadCategoryTrend(categories.first.id);
    }
  }

  Future<void> _onHeatmapPageChanged(DateTime focusedMonth) async {
    final monthStart = DateTime(focusedMonth.year, focusedMonth.month, 1);
    setState(() => _heatmapMonth = monthStart);
    await context.read<AnalyticsProvider>().loadDailyExpenses(
          monthStart,
          DateTime(monthStart.year, monthStart.month + 1, 0),
        );
  }

  /// Opens the transactions behind a heatmap cell. The heatmap only ever
  /// showed intensity, so a dark day raised the obvious question — what was
  /// it? — with no way to answer it without leaving for the history screen
  /// and filtering by hand.
  void _showDayTransactions(DateTime day) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DayTransactionsSheet(day: day),
    );
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
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        children: [
          Text(loc.cashflow, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppConstants.spacingMd),
          _CashflowChart(
            data: analytics.cashflow,
            symbol: settings.currencySymbol,
            useDecimals: settings.currencyUseDecimals,
          ),
          const SizedBox(height: AppConstants.spacingXxxl),

          Text(loc.categoryTrend, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppConstants.spacingMd),
          _CategoryTrendSection(
            categories: categoryProvider.expenseCategories,
            selectedCategoryId: _trendCategoryId,
            onChanged: _onTrendCategoryChanged,
            data: analytics.categoryTrend,
            symbol: settings.currencySymbol,
            useDecimals: settings.currencyUseDecimals,
          ),
          const SizedBox(height: AppConstants.spacingXxxl),

          Text(loc.spendingHeatmap, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppConstants.spacingMd),
          _SpendingHeatmap(
            dailyExpenses: analytics.dailyExpenses,
            focusedMonth: _heatmapMonth,
            onPageChanged: _onHeatmapPageChanged,
            onDaySelected: _showDayTransactions,
            symbol: settings.currencySymbol,
            useDecimals: settings.currencyUseDecimals,
          ),
          const SizedBox(height: AppConstants.spacingXxxl),
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
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (totalNet >= 0 ? incomeColor : expenseColor).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            loc.netCashflowOverMonths(
              data.length,
              NumberUtils.formatCurrency(totalNet, symbol: symbol, useDecimals: useDecimals),
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              color: totalNet >= 0 ? incomeColor : expenseColor,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            for (final c in categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
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
              ),
            ),
          ),
          if (callout != null) ...[
            const SizedBox(height: AppConstants.spacingMd),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (callout.isAbove ? AppColors.warning : theme.colorScheme.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                callout.isAbove
                    ? loc.categoryAboveAverage(callout.percent.toStringAsFixed(0), data.length - 1)
                    : loc.categoryBelowAverage(callout.percent.toStringAsFixed(0), data.length - 1),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: callout.isAbove ? AppColors.warning : theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SpendingHeatmap extends StatelessWidget {
  final Map<String, double> dailyExpenses;
  final DateTime focusedMonth;
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<DateTime> onDaySelected;
  final String symbol;
  final bool useDecimals;

  const _SpendingHeatmap({
    required this.dailyExpenses,
    required this.focusedMonth,
    required this.onPageChanged,
    required this.onDaySelected,
    required this.symbol,
    required this.useDecimals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final expenseColor = isDark ? AppColors.darkExpense : AppColors.lightExpense;

    final maxDay = dailyExpenses.values.isEmpty
        ? 0.0
        : dailyExpenses.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(AppConstants.spacingSm),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedMonth,
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            availableGestures: AvailableGestures.horizontalSwipe,
            onPageChanged: onPageChanged,
            onDaySelected: (selected, _) => onDaySelected(selected),
            daysOfWeekVisible: true,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) => _dayCell(context, day, maxDay, expenseColor),
              todayBuilder: (context, day, focusedDay) => _dayCell(context, day, maxDay, expenseColor, isToday: true),
              outsideBuilder: (context, day, focusedDay) => _dayCell(context, day, maxDay, expenseColor, isOutside: true),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Text(loc.heatmapTapHint, style: theme.textTheme.labelSmall),
      ],
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day,
    double maxDay,
    Color expenseColor, {
    bool isToday = false,
    bool isOutside = false,
  }) {
    final theme = Theme.of(context);
    final key = AppDateUtils.formatIso(day);
    final amount = dailyExpenses[key] ?? 0;
    final intensity = maxDay > 0 ? (amount / maxDay).clamp(0.0, 1.0) : 0.0;

    // Tooltip rather than an always-on label: the cell is barely wide
    // enough for the date, and the tap sheet is the real answer.
    return Tooltip(
      message: amount > 0
          ? NumberUtils.formatCurrency(amount, symbol: symbol, useDecimals: useDecimals)
          : '',
      excludeFromSemantics: amount <= 0,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: intensity > 0 ? expenseColor.withValues(alpha: 0.15 + intensity * 0.55) : null,
          borderRadius: BorderRadius.circular(6),
          border: isToday ? Border.all(color: theme.colorScheme.primary, width: 1.5) : null,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: intensity > 0.4
                  ? Colors.white
                  : (isOutside
                      ? theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4)
                      : theme.textTheme.bodyMedium?.color),
              fontWeight: intensity > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything that happened on one heatmap day.
///
/// Shows income alongside expenses even though the heatmap itself is
/// expense-only — the question a tap asks is "what happened on this day",
/// and a salary landing is part of that answer. The header total is
/// recomputed from the listed transactions rather than read out of
/// `dailyExpenses`, so the two can't disagree.
class _DayTransactionsSheet extends StatelessWidget {
  final DateTime day;

  const _DayTransactionsSheet({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final key = AppDateUtils.formatIso(day);

    final transactions = context
        .watch<TransactionProvider>()
        .allTransactions
        .where((t) => AppDateUtils.formatIso(t.date) == key)
        .toList();

    final spent = transactions
        .where((t) => !t.isIncome && !t.isTransfer)
        .fold<double>(0, (sum, t) => sum + t.amount);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: AppConstants.spacingSm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppDateUtils.formatFull(day), style: theme.textTheme.titleLarge),
                        Text(loc.totalSpent, style: theme.textTheme.labelMedium),
                      ],
                    ),
                  ),
                  Text(
                    NumberUtils.formatCurrency(
                      spent,
                      symbol: settings.currencySymbol,
                      useDecimals: settings.currencyUseDecimals,
                    ),
                    style: AppTypography.amountStyle(
                      color: theme.textTheme.bodyLarge!.color!,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: transactions.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: loc.noTransactionsOnThisDay,
                      subtitle: '',
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spacingLg,
                        0,
                        AppConstants.spacingLg,
                        AppConstants.spacingLg,
                      ),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) =>
                          TransactionTile(transaction: transactions[index], dense: true),
                    ),
            ),
          ],
        );
      },
    );
  }
}

