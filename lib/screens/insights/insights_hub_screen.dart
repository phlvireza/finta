import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/insights_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/health_score.dart';
import '../../core/utils/insight_rules.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../transactions/widgets/transaction_tile.dart';
import '../../l10n/app_localizations.dart';

/// The intelligence layer's home: financial health score, rule-based
/// spending insights, and unusual-activity flags — everything
/// [InsightsProvider] computes from on-device statistics, no cloud calls.
class InsightsHubScreen extends StatefulWidget {
  const InsightsHubScreen({super.key});

  @override
  State<InsightsHubScreen> createState() => _InsightsHubScreenState();
}

class _InsightsHubScreenState extends State<InsightsHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final settings = context.read<SettingsProvider>();
    final txProvider = context.read<TransactionProvider>();
    final budgetProvider = context.read<BudgetProvider>();

    final period = txProvider.period ?? AppDateUtils.getCurrentPeriod(settings.payday);
    final previousPeriod = AppDateUtils.getPreviousPeriod(period);

    var totalBudgeted = 0.0;
    var totalSpentAgainstBudgets = 0.0;
    for (final status in budgetProvider.budgetStatuses.values) {
      totalBudgeted += status.effectiveAmount;
      totalSpentAgainstBudgets += status.spent;
    }

    await context.read<InsightsProvider>().loadAll(
          currentPeriod: period,
          previousPeriod: previousPeriod,
          currentIncome: txProvider.totalIncome,
          currentExpense: txProvider.totalExpense,
          payday: settings.payday,
          totalBudgeted: totalBudgeted > 0 ? totalBudgeted : null,
          totalSpentAgainstBudgets: totalSpentAgainstBudgets,
        );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final insights = context.watch<InsightsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(loc.smartInsights)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: insights.isLoading && insights.healthScore == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingLg,
                  AppConstants.spacingMd,
                  AppConstants.spacingLg,
                  AppConstants.spacingLg,
                ),
                children: [
                  if (insights.healthScore != null) ...[
                    _HealthScoreCard(breakdown: insights.healthScore!),
                    const SizedBox(height: AppConstants.spacingLg),
                  ],
                  SectionCard(
                    title: loc.spendingInsightsTitle,
                    child: insights.spendingInsights.isEmpty
                        ? EmptyState(icon: Icons.insights_outlined, title: loc.noInsightsYet, subtitle: '')
                        : Column(
                            children: [
                              for (var i = 0; i < insights.spendingInsights.length; i++) ...[
                                if (i > 0) const Divider(height: AppConstants.spacingXl),
                                _InsightCard(data: insights.spendingInsights[i]),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                  SectionCard(
                    title: loc.unusualActivity,
                    child: insights.unusualTransactions.isEmpty
                        ? EmptyState(icon: Icons.check_circle_outline, title: loc.noUnusualActivity, subtitle: '')
                        : Column(
                            children: [
                              for (var i = 0; i < insights.unusualTransactions.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                TransactionTile(transaction: insights.unusualTransactions[i], dense: true),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  final HealthScoreBreakdown breakdown;

  const _HealthScoreCard({required this.breakdown});

  Color _scoreColor(BuildContext context, int score) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (score >= 70) return isDark ? AppColors.darkIncome : AppColors.lightIncome;
    if (score >= 40) return AppColors.warning;
    return isDark ? AppColors.darkExpense : AppColors.lightExpense;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final color = _scoreColor(context, breakdown.overall);

    return SectionCard(
      title: loc.financialHealthScore,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                '${breakdown.overall}',
                style: AppTypography.amountStyle(color: color, fontSize: 40, fontWeight: FontWeight.w700),
              ),
              Text(loc.outOfHundred, style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(width: AppConstants.spacingXl),
          Expanded(
            child: Column(
              children: [
                // Each bar keeps one fixed hue — it identifies *which*
                // metric it is, not how good it is. Colouring the bars by
                // score instead made the card three identical green bars
                // for anyone doing broadly fine, which said nothing. The
                // number beside each label still carries the verdict.
                _breakdownRow(
                  context,
                  loc.healthScoreSavings,
                  breakdown.savingsScore,
                  isDark ? AppColors.darkIncome : AppColors.lightIncome,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                _breakdownRow(
                  context,
                  loc.healthScoreBudget,
                  breakdown.budgetScore,
                  AppColors.warning,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                _breakdownRow(
                  context,
                  loc.healthScoreStability,
                  breakdown.stabilityScore,
                  // The blue from the chart ramp — the one hue in the
                  // palette that carries no good/bad connotation.
                  (isDark ? AppColors.chartColorsDark : AppColors.chartColorsLight)[5],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [barColor] identifies the metric; the score's own [_scoreColor] still
  /// tints the number, so a bad sub-score stays obvious at a glance.
  Widget _breakdownRow(
    BuildContext context,
    String label,
    int score,
    Color barColor,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Text(
              '$score',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _scoreColor(context, score),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 4,
            // Tinted with the bar's own hue rather than the neutral surface,
            // matching the budget bars.
            backgroundColor: barColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final SpendingInsightData data;

  const _InsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final category = context.watch<CategoryProvider>().getCategoryById(data.categoryId);
    final categoryName = category?.name ?? loc.unknown;
    final percent = data.percent.toStringAsFixed(0);

    final String title;
    final String body;
    final IconData icon;
    final Color color;
    final isDark = theme.brightness == Brightness.dark;
    switch (data.kind) {
      case InsightKind.fastestGrowing:
        title = loc.insightFastestGrowingTitle(categoryName);
        body = loc.insightFastestGrowingBody(percent);
        icon = Icons.local_fire_department_outlined;
        color = AppColors.warning;
        break;
      case InsightKind.increase:
        title = loc.insightSpendingIncreasedTitle(categoryName);
        body = loc.insightSpendingIncreasedBody(percent);
        icon = Icons.trending_up;
        color = isDark ? AppColors.darkExpense : AppColors.lightExpense;
        break;
      case InsightKind.decrease:
        title = loc.insightSpendingDecreasedTitle(categoryName);
        body = loc.insightSpendingDecreasedBody(percent);
        icon = Icons.trending_down;
        color = isDark ? AppColors.darkIncome : AppColors.lightIncome;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppConstants.tintAlpha),
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppConstants.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall,
              ),
              Text(body, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
