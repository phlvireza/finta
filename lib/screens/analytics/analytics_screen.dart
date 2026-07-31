import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/category_rollup.dart';
import 'widgets/breakdown_chart.dart';
import 'widgets/category_rank_list.dart';
import 'widgets/yearly_report.dart';
import 'widgets/trends_report.dart';
import '../budgets/widgets/budget_progress_bar.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/widgets/type_toggle.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/error_state.dart';
import '../../l10n/app_localizations.dart';
import '../../core/constants/app_colors.dart';

/// Insights — a single scrollable report (donut breakdown, budget
/// performance, reports) instead of the old Expense/Income tab pair, so
/// the period selector applies to the whole page rather than one tab.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isIncome = false;
  bool _expandSubcategories = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final settings = context.read<SettingsProvider>();
    await context.read<AnalyticsProvider>().loadForCurrentPeriod(settings.payday);
  }

  void _openYearlyReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const YearlyReportScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final analytics = context.watch<AnalyticsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(loc.analytics)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingMd,
              AppConstants.spacingLg,
              AppConstants.spacingMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AnalyticsPeriod>(
                      value: analytics.selectedPeriod,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(value: AnalyticsPeriod.weekly, child: Text(loc.weekly)),
                        DropdownMenuItem(value: AnalyticsPeriod.biweekly, child: Text(loc.biweekly)),
                        DropdownMenuItem(value: AnalyticsPeriod.monthly, child: Text(loc.monthly)),
                        DropdownMenuItem(value: AnalyticsPeriod.yearly, child: Text(loc.year)),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        if (val == AnalyticsPeriod.yearly) {
                          // Yearly data is a monthly trend, not a category
                          // breakdown — a different shape from what this
                          // page renders, so open the dedicated report
                          // rather than half-rendering it here.
                          _openYearlyReport();
                          return;
                        }
                        final settings = context.read<SettingsProvider>();
                        analytics.setPeriodFilter(val, settings.payday);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: analytics.isLoading
                  ? const SkeletonAnalytics()
                  : analytics.error != null
                      ? ErrorState(
                          title: 'Failed to load analytics',
                          message: analytics.error,
                          onRetry: _loadData,
                        )
                      : ListView(
                          padding: const EdgeInsets.only(bottom: AppConstants.fabClearance),
                          children: [
                            _SectionTitle(loc.whereItWent),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                              child: TypeToggle(
                                isIncome: _isIncome,
                                onChanged: (val) => setState(() => _isIncome = val),
                                expenseLabel: loc.expense,
                                incomeLabel: loc.income,
                              ),
                            ),
                            _BreakdownSection(
                              isIncome: _isIncome,
                              expandSubcategories: _expandSubcategories,
                              onToggleExpand: () => setState(
                                () => _expandSubcategories = !_expandSubcategories,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingXxxl),
                            _SectionTitle(loc.budgetPerformance),
                            const _BudgetPerformanceSection(),
                            const SizedBox(height: AppConstants.spacingXxxl),
                            _SectionTitle(loc.reports),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                              child: Card(
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.bar_chart),
                                      title: Text(loc.yearlyReport),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: _openYearlyReport,
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(Icons.trending_up),
                                      title: Text(loc.trends),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const TrendsReportScreen()),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingMd,
      ),
      child: Text(title, style: theme.textTheme.titleLarge),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  final bool isIncome;
  final bool expandSubcategories;
  final VoidCallback onToggleExpand;

  const _BreakdownSection({
    required this.isIncome,
    required this.expandSubcategories,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<AnalyticsProvider>();
    final categories = context.watch<CategoryProvider>();
    final loc = AppLocalizations.of(context)!;
    final raw = isIncome ? analytics.incomeBreakdown : analytics.expenseBreakdown;
    final hasSubcategories = raw.any((d) => categories.getCategoryById(d.categoryId)?.isSubcategory == true);
    final data = expandSubcategories ? raw : rollUpToParents(raw, categories.getCategoryById);
    final total = isIncome ? analytics.totalIncome : analytics.totalExpense;

    if (data.isEmpty) {
      return EmptyState(
        icon: Icons.pie_chart_outline,
        title: loc.noDataForThisPeriod,
        subtitle: '',
        action: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddTransactionScreen(),
              fullscreenDialog: true,
            ),
          ),
          icon: const Icon(Icons.add),
          label: Text(loc.addTransactionCta),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: AppConstants.spacingLg),
        SizedBox(
          height: 240,
          child: BreakdownChart(data: data, total: total),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Center(
          child: _buildComparison(
            context,
            total,
            isIncome ? analytics.previousTotalIncome : analytics.previousTotalExpense,
          ),
        ),
        if (hasSubcategories)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onToggleExpand,
                icon: Icon(expandSubcategories ? Icons.unfold_less : Icons.unfold_more, size: 18),
                label: Text(
                  expandSubcategories ? loc.groupSubcategories : loc.showSubcategories,
                ),
              ),
            ),
          ),
        const SizedBox(height: AppConstants.spacingXxxl),
        CategoryRankList(data: data),
      ],
    );
  }

  Widget _buildComparison(BuildContext context, double current, double previous) {
    if (previous == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final diff = current - previous;
    final percent = (diff.abs() / previous) * 100;

    final isMore = diff > 0;
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    IconData icon;
    if (isIncome) {
      color = isMore
          ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
          : (isDark ? AppColors.darkExpense : AppColors.lightExpense);
      icon = isMore ? Icons.arrow_upward : Icons.arrow_downward;
    } else {
      color = isMore
          ? (isDark ? AppColors.darkExpense : AppColors.lightExpense)
          : (isDark ? AppColors.darkIncome : AppColors.lightIncome);
      icon = isMore ? Icons.arrow_upward : Icons.arrow_downward;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${percent.toStringAsFixed(1)}% ${isMore ? 'more' : 'less'} than last period',
            style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BudgetPerformanceSection extends StatelessWidget {
  const _BudgetPerformanceSection();

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context)!;
    final statuses = budgetProvider.budgetStatuses.values.toList();

    if (statuses.isEmpty) {
      return EmptyState(
        icon: Icons.pie_chart_outline,
        title: loc.createFirstBudget,
        subtitle: '',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        children: statuses.map((status) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
            child: BudgetProgressBar(
              status: status,
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
              payday: settings.payday,
            ),
          );
        }).toList(),
      ),
    );
  }
}
