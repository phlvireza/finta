import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/insights_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/health_score.dart';
import '../../core/utils/insight_rules.dart';
import '../../widgets/empty_state.dart';
import '../dashboard/widgets/forecast_card.dart';
import '../transactions/widgets/transaction_tile.dart';
import '../../l10n/app_localizations.dart';

/// The intelligence layer's home: financial health score, projected spend,
/// rule-based spending insights, and unusual-activity flags — everything
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
                padding: const EdgeInsets.all(AppConstants.spacingLg),
                children: [
                  if (insights.healthScore != null) ...[
                    Text(loc.financialHealthScore, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppConstants.spacingMd),
                    _HealthScoreCard(breakdown: insights.healthScore!),
                    const SizedBox(height: AppConstants.spacingXxxl),
                  ],
                  const ForecastCard(),
                  const SizedBox(height: AppConstants.spacingXxxl),
                  Text(loc.spendingInsightsTitle, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppConstants.spacingMd),
                  if (insights.spendingInsights.isEmpty)
                    EmptyState(icon: Icons.insights_outlined, title: loc.noInsightsYet, subtitle: '')
                  else
                    ...insights.spendingInsights.map((i) => _InsightCard(data: i)),
                  const SizedBox(height: AppConstants.spacingXxxl),
                  Text(loc.unusualActivity, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppConstants.spacingMd),
                  if (insights.unusualTransactions.isEmpty)
                    EmptyState(icon: Icons.check_circle_outline, title: loc.noUnusualActivity, subtitle: '')
                  else
                    ...insights.unusualTransactions.map((t) => TransactionTile(transaction: t)),
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
    final color = _scoreColor(context, breakdown.overall);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${breakdown.overall}',
                  style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppConstants.spacingLg),
              Expanded(
                child: Text(
                  loc.healthScoreOutOf100,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
          _breakdownRow(context, loc.healthScoreSavings, breakdown.savingsScore),
          const SizedBox(height: AppConstants.spacingSm),
          _breakdownRow(context, loc.healthScoreBudget, breakdown.budgetScore),
          const SizedBox(height: AppConstants.spacingSm),
          _breakdownRow(context, loc.healthScoreStability, breakdown.stabilityScore),
        ],
      ),
    );
  }

  Widget _breakdownRow(BuildContext context, String label, int score) {
    final theme = Theme.of(context);
    final color = _scoreColor(context, score);
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: theme.textTheme.labelMedium)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        SizedBox(width: 32, child: Text('$score', style: theme.textTheme.labelSmall, textAlign: TextAlign.right)),
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

    final String message;
    final IconData icon;
    final Color color;
    final isDark = theme.brightness == Brightness.dark;
    switch (data.kind) {
      case InsightKind.fastestGrowing:
        message = loc.insightFastestGrowing(categoryName, percent);
        icon = Icons.local_fire_department_outlined;
        color = AppColors.warning;
        break;
      case InsightKind.increase:
        message = loc.insightSpendingIncreased(categoryName, percent);
        icon = Icons.trending_up;
        color = isDark ? AppColors.darkExpense : AppColors.lightExpense;
        break;
      case InsightKind.decrease:
        message = loc.insightSpendingDecreased(categoryName, percent);
        icon = Icons.trending_down;
        color = isDark ? AppColors.darkIncome : AppColors.lightIncome;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
