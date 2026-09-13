import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/budget_health.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/masked_amount.dart';
import '../../../widgets/status_pill.dart';
import '../budget_overview_data.dart';
import 'budget_pace_bar.dart';

class BudgetSummaryCard extends StatelessWidget {
  final List<BudgetStatus> statuses;
  final SettingsProvider settings;
  final String? cadenceLabel;

  const BudgetSummaryCard({
    super.key,
    required this.statuses,
    required this.settings,
    this.cadenceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final totals = BudgetOverviewTotals.fromStatuses(statuses);
    final usageRatio = totals.usageRatio;
    final heroValue = totals.isOverspent ? totals.overspent : totals.remaining;
    final health = _overallHealth(statuses);
    final statusColor = health == BudgetHealth.overLimit
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final statusLabel = switch (health) {
      BudgetHealth.overLimit => loc.budgetOverLimit,
      BudgetHealth.needsAttention => loc.budgetNeedsAttention,
      BudgetHealth.withinLimits => loc.budgetWithinLimits,
    };
    String money(double value) => NumberUtils.formatCurrencyLocalized(
      value,
      locale: locale,
      symbol: settings.currencySymbol,
      useDecimals: settings.currencyUseDecimals,
    );
    final usageLabel = usageRatio == null
        ? null
        : '${NumberUtils.formatPercentage(usageRatio)} ${loc.used}';
    final progressSemantics = settings.hideBalances
        ? loc.budgetTotalProgressHidden
        : [
            loc.budgetTotalUsage,
            ?usageLabel,
            loc.spentOfTotal(money(totals.spent), money(totals.budgeted)),
          ].join('. ');
    final hero = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          totals.isOverspent ? loc.budgetOverByLabel : loc.leftThisPeriod,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: MaskedAmount(
              text: money(heroValue),
              maxLines: 1,
              style: AppTypography.amountStyle(
                color: totals.isOverspent
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
    final status = StatusPill(label: statusLabel, color: statusColor);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (largeText) ...[
          hero,
          const SizedBox(height: AppConstants.spacingMd),
          status,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: hero),
              const SizedBox(width: AppConstants.spacingMd),
              status,
            ],
          ),
        const SizedBox(height: AppConstants.spacingSm),
        Text(
          [
            ?cadenceLabel,
            loc.activeBudgetCount(totals.count),
            AppDateUtils.formatPeriodRange(
              statuses.first.period.start,
              statuses.first.period.end,
            ),
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppConstants.spacingXl),
        Semantics(
          container: true,
          label: progressSemantics,
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        loc.budgetTotalUsage,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (usageLabel != null) ...[
                      const SizedBox(width: AppConstants.spacingMd),
                      Text(
                        usageLabel,
                        key: const ValueKey('budget-total-usage-label'),
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                BudgetPaceBar(
                  key: const ValueKey('budget-total-progress'),
                  ratio: usageRatio ?? (totals.spent > 0 ? 1 : 0),
                  timeElapsedFraction: AppDateUtils.periodElapsedFraction(
                    statuses.first.period,
                  ),
                  barColor: totals.isOverspent
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  showPaceMarker: usageRatio != null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingXl),
        LayoutBuilder(
          builder: (context, constraints) {
            const metricSpacing = 8.0;
            final inlineMetricWidth =
                (constraints.maxWidth - (metricSpacing * 2)) / 3;
            final displayedValues = settings.hideBalances
                ? const ['••••••', '••••••', '••••••']
                : [
                    money(totals.budgeted),
                    money(totals.spent),
                    money(heroValue),
                  ];
            final useStackedMetrics =
                largeText ||
                displayedValues.any(
                  (value) => !_fitsInlineMetric(
                    context,
                    value: value,
                    availableWidth: inlineMetricWidth,
                  ),
                );
            final metricWidth = useStackedMetrics
                ? constraints.maxWidth
                : inlineMetricWidth;
            return Wrap(
              spacing: metricSpacing,
              runSpacing: AppConstants.spacingMd,
              children: [
                _Metric(
                  key: const ValueKey('budget-summary-budgeted-metric'),
                  width: metricWidth,
                  label: loc.budgetedLabel,
                  value: money(totals.budgeted),
                ),
                _Metric(
                  key: const ValueKey('budget-summary-spent-metric'),
                  width: metricWidth,
                  label: loc.spent,
                  value: money(totals.spent),
                ),
                _Metric(
                  key: const ValueKey('budget-summary-remaining-metric'),
                  width: metricWidth,
                  label: totals.isOverspent
                      ? loc.budgetOverLimit
                      : loc.remaining,
                  value: money(heroValue),
                  valueColor: totals.isOverspent
                      ? theme.colorScheme.error
                      : null,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  bool _fitsInlineMetric(
    BuildContext context, {
    required String value,
    required double availableWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: AppTypography.amountStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.localeOf(context),
    )..layout();
    final fits = painter.width <= availableWidth;
    painter.dispose();
    return fits;
  }

  BudgetHealth _overallHealth(List<BudgetStatus> items) {
    var result = BudgetHealth.withinLimits;
    for (final status in items) {
      final health = budgetHealthFor(
        status,
        AppDateUtils.periodElapsedFraction(status.period),
      );
      if (health == BudgetHealth.overLimit) return health;
      if (health == BudgetHealth.needsAttention) {
        result = BudgetHealth.needsAttention;
      }
    }
    return result;
  }
}

class _Metric extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final Color? valueColor;

  const _Metric({
    super.key,
    required this.width,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: AppConstants.spacingXs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: MaskedAmount(
                text: value,
                maxLines: 1,
                style: AppTypography.amountStyle(
                  color: valueColor ?? theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
