import 'package:flutter/material.dart';
import '../../../core/utils/budget_health.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';
import '../budget_detail_screen.dart';
import 'budget_progress_bar.dart';

class BudgetHealthCard extends StatelessWidget {
  final BudgetProvider budgetProvider;
  final SettingsProvider settings;
  const BudgetHealthCard({
    super.key,
    required this.budgetProvider,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final statuses = budgetProvider.activeBudgets
        .map((b) => budgetProvider.budgetStatuses[b.id])
        .whereType<BudgetStatus>()
        .toList();
    double elapsed(BudgetStatus s) =>
        AppDateUtils.periodElapsedFraction(s.period);
    final ranked = prioritizeBudgets(statuses, elapsed);
    final counts = {
      for (final health in BudgetHealth.values)
        health: statuses
            .where((s) => budgetHealthFor(s, elapsed(s)) == health)
            .length,
    };
    final labels = [
      loc.budgetOverLimit,
      loc.budgetNeedsAttention,
      loc.budgetWithinLimits,
    ];
    final icons = [
      Icons.error_outline,
      Icons.visibility_outlined,
      Icons.check_circle_outline,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.budgetHealth,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          loc.activeBudgetCount(budgetProvider.activeBudgets.length),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Text(loc.budgetHealthSubtitle, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final health in BudgetHealth.values)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[health.index],
                      size: 20,
                      color:
                          health == BudgetHealth.overLimit &&
                              counts[health]! > 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${counts[health]} ${labels[health.index]}',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (ranked.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            counts[BudgetHealth.overLimit] == 0 &&
                    counts[BudgetHealth.needsAttention] == 0
                ? loc.budgetAllHealthy
                : loc.budgetPriority,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(loc.budgetTimeMarker, style: theme.textTheme.bodySmall),
          for (final status in ranked.take(3)) ...[
            const SizedBox(height: 12),
            Material(
              key: ValueKey(status.budget.id),
              color: theme.colorScheme.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        BudgetDetailScreen(budgetId: status.budget.id),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BudgetProgressBar(
                    status: status,
                    symbol: settings.currencySymbol,
                    useDecimals: settings.currencyUseDecimals,
                    compact: true,
                    summary: true,
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
