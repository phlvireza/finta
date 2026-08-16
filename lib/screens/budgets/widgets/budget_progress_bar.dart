import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/budget_display.dart';
import '../../../l10n/app_localizations.dart';
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

  const BudgetProgressBar({
    super.key,
    required this.status,
    required this.symbol,
    required this.useDecimals,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final categories = context.watch<CategoryProvider>();
    final display = resolveBudgetDisplay(
      budget: status.budget,
      categories: categories,
      loc: loc,
      fallbackColor: theme.colorScheme.primary,
    );

    final barColor = AppColors.budgetBarColor(
      isExceeded: status.isExceeded,
      isWarning: status.isWarning,
      categoryColor: display.color,
      isDark: isDark,
    );

    final ratio = status.ratio.clamp(0.0, 1.0);
    final timeElapsed = AppDateUtils.periodElapsedFraction(status.period);
    final paceLabel = budgetPaceLabel(loc, budgetPaceFor(status.ratio, timeElapsed));

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: display.color.withValues(alpha: AppConstants.tintAlpha),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Icon(display.icon, size: 16, color: display.color),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Text(display.title, style: theme.textTheme.titleMedium),
            ),
            Text(
              '${NumberUtils.formatPercentage(ratio)} ${loc.used}',
              style: theme.textTheme.labelMedium?.copyWith(color: barColor),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMd),
        BudgetPaceBar(
          ratio: ratio,
          timeElapsedFraction: timeElapsed,
          barColor: barColor,
        ),
        const SizedBox(height: AppConstants.spacingSm),
        // One split caption line instead of a pace row followed by a
        // separate amounts row: the pace verdict on the left, the amount
        // left (or the over-budget flag) on the right.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paceLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(width: 2),
                InkWell(
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                  onTap: () => _showPaceInfo(context, loc),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.info_outline,
                      size: 13,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
            Flexible(
              child: Text(
                status.isExceeded
                    ? loc.overBudget
                    : '${NumberUtils.formatCurrency(status.remaining, symbol: symbol, useDecimals: useDecimals)} ${loc.left}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: status.isExceeded ? barColor : theme.textTheme.bodySmall?.color,
                  fontWeight: status.isExceeded ? FontWeight.bold : null,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // "spent of budgeted" — without the budget on the row there is
        // nothing to check the percentage above against. Uses
        // effectiveAmount, not budget.amount, so it agrees with the ratio;
        // any gap between the two is what the rollover line below explains.
        const SizedBox(height: 2),
        Text(
          '${NumberUtils.formatCurrency(status.spent, symbol: symbol, useDecimals: useDecimals)} '
          '${loc.ofString} '
          '${NumberUtils.formatCurrency(status.effectiveAmount, symbol: symbol, useDecimals: useDecimals)}',
          style: theme.textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
        if (status.budget.hasRollover && status.rolloverAmount != 0) ...[
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            status.rolloverAmount > 0
                ? loc.rolledOverPositive(
                    NumberUtils.formatCurrency(status.rolloverAmount, symbol: symbol, useDecimals: useDecimals),
                  )
                : loc.rolledOverNegative(
                    NumberUtils.formatCurrency(-status.rolloverAmount, symbol: symbol, useDecimals: useDecimals),
                  ),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.textTheme.bodySmall?.color),
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
