import '../../../core/utils/budget_health.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/budget_display.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/masked_amount.dart';
import 'budget_pace_bar.dart';

/// Progress bar visualizing budget usage — works for any scope
/// (category/group/overall) and any period length, via
/// [resolveBudgetDisplay] and the range [BudgetStatus] was measured over.
///
/// [compact] drops the row's own card decoration for use inside a
/// [SectionCard] that already supplies one — the Budgets list hosts every
/// active budget in a single card rather than bordering each row on its
/// own, so only one of the two callers (the standalone use on
/// [BudgetDetailScreen]) needs the full decoration.
class BudgetProgressBar extends StatelessWidget {
  final BudgetStatus status;
  final String symbol;
  final bool useDecimals;
  final bool compact;
  final bool summary;

  const BudgetProgressBar({
    super.key,
    required this.status,
    required this.symbol,
    required this.useDecimals,
    this.compact = false,
    this.summary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final categories = context.watch<CategoryProvider>();
    final display = resolveBudgetDisplay(
      budget: status.budget,
      categories: categories,
      loc: loc,
      fallbackColor: theme.colorScheme.primary,
    );

    final timeElapsed = AppDateUtils.periodElapsedFraction(status.period);
    final health = budgetHealthFor(status, timeElapsed);
    final barColor = health == BudgetHealth.overLimit
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final hasLimit = status.effectiveAmount > 0;
    final ratio = hasLimit
        ? status.ratio
        : health == BudgetHealth.overLimit
        ? 1.0
        : 0.0;
    final healthLabel = !hasLimit
        ? loc.noAvailableBudget
        : status.ratio == 1
        ? loc.budgetLimitReached
        : switch (health) {
            BudgetHealth.overLimit => loc.budgetOverLimit,
            BudgetHealth.needsAttention => loc.budgetNeedsAttention,
            BudgetHealth.withinLimits => loc.budgetWithinLimits,
          };
    String money(double amount) => NumberUtils.formatCurrencyLocalized(
      amount,
      locale: locale,
      symbol: symbol,
      useDecimals: useDecimals,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: AppConstants.tintAlpha,
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Icon(
                display.icon,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Text(display.title, style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              healthLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasLimit)
              Text(
                '${NumberUtils.formatPercentage(status.ratio)} ${loc.used}',
                style: theme.textTheme.labelMedium,
              ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Semantics(
          label: '${display.title}: $healthLabel',
          child: BudgetPaceBar(
            ratio: ratio,
            timeElapsedFraction: timeElapsed,
            barColor: barColor,
            height: 12,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        MaskedAmount(
          text: health == BudgetHealth.overLimit
              ? loc.budgetOverspentAmount(
                  money(status.spent - status.effectiveAmount),
                )
              : '${money(status.remaining)} ${loc.left}',
          style: AppTypography.amountStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!summary) ...[
          const SizedBox(height: 4),
          MaskedAmount(
            text:
                '${money(status.spent)} ${loc.ofString} ${money(status.effectiveAmount)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 4),
        Text(
          AppDateUtils.formatPeriodRange(
            status.period.start,
            status.period.end,
          ),
          style: theme.textTheme.bodySmall,
        ),
        if (!summary)
          TextButton.icon(
            onPressed: () => _showPaceInfo(context, loc),
            icon: const Icon(Icons.info_outline, size: 18),
            label: Text(loc.budgetTimeMarker),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 0),
            ),
          ),

        if (status.budget.hasRollover && status.rolloverAmount != 0) ...[
          const SizedBox(height: AppConstants.spacingXs),
          MaskedAmount(
            text: status.rolloverAmount > 0
                ? loc.rolledOverPositive(
                    NumberUtils.formatCurrencyLocalized(
                      status.rolloverAmount,
                      locale: locale,
                      symbol: symbol,
                      useDecimals: useDecimals,
                    ),
                  )
                : loc.rolledOverNegative(
                    NumberUtils.formatCurrencyLocalized(
                      -status.rolloverAmount,
                      locale: locale,
                      symbol: symbol,
                      useDecimals: useDecimals,
                    ),
                  ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ],
    );

    if (compact) return content;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: content,
    );
  }

  void _showPaceInfo(BuildContext context, AppLocalizations loc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.paceInfoTitle),
        content: Text(loc.paceExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.gotIt),
          ),
        ],
      ),
    );
  }
}
