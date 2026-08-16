import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/daily_totals.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_card.dart';
import '../../transactions/widgets/transaction_tile.dart';
import '../../../l10n/app_localizations.dart';

/// Day-by-day spending intensity for the current pay period.
///
/// This used to be a `TableCalendar` on the trends report, paging calendar
/// *months*. On a payday-anchored dashboard that was the wrong unit — the
/// grid would have straddled two periods while every other card described
/// one — so it is drawn here as a grid of exactly the period's days and
/// follows the period selector like everything else on the screen.
///
/// It also needs no query of its own: [TransactionProvider.transactions] is
/// already the selected period's rows, so the totals are derived rather than
/// fetched.
class SpendingHeatmap extends StatelessWidget {
  const SpendingHeatmap({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final transactions = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final period = transactions.period;
    if (period == null) return const SizedBox.shrink();

    final totals = dailyExpenseTotals(transactions.transactions);
    final maxDay = maxDailyTotal(totals);

    final materialLoc = MaterialLocalizations.of(context);
    final firstWeekday = materialLoc.firstDayOfWeekIndex;

    final days = _daysIn(period);
    // Blank cells so the first day of the period sits under its own weekday
    // column. DateTime.weekday is 1..7 with Sunday last; % 7 folds Sunday
    // back to 0, which is the index narrowWeekdays uses.
    final leadingBlanks = (days.first.weekday % 7 - firstWeekday + 7) % 7;

    final isDark = theme.brightness == Brightness.dark;
    final expenseColor = isDark ? AppColors.darkExpense : AppColors.lightExpense;

    return SectionCard(
      title: loc.spendingHeatmap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    materialLoc.narrowWeekdays[(firstWeekday + i) % 7],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: AppConstants.spacingXs,
              crossAxisSpacing: AppConstants.spacingXs,
            ),
            itemCount: leadingBlanks + days.length,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();
              final day = days[index - leadingBlanks];
              return _DayCell(
                day: day,
                amount: totals[day] ?? 0,
                maxDay: maxDay,
                expenseColor: expenseColor,
                symbol: settings.currencySymbol,
                useDecimals: settings.currencyUseDecimals,
                onTap: () => _showDayTransactions(context, day),
              );
            },
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(loc.heatmapTapHint, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  /// Every date-only day in the period, inclusive of both ends.
  List<DateTime> _daysIn(({DateTime start, DateTime end}) period) {
    final start = DateTime(period.start.year, period.start.month, period.start.day);
    final end = DateTime(period.end.year, period.end.month, period.end.day);
    final days = <DateTime>[];
    for (var day = start; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
      days.add(DateTime(day.year, day.month, day.day));
    }
    return days;
  }

  /// Opens the transactions behind a cell. The grid only ever shows
  /// intensity, so a dark day raised the obvious question — what was it? —
  /// with no way to answer it without leaving for the history screen and
  /// filtering by hand.
  void _showDayTransactions(BuildContext context, DateTime day) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DayTransactionsSheet(day: day),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final double amount;
  final double maxDay;
  final Color expenseColor;
  final String symbol;
  final bool useDecimals;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.amount,
    required this.maxDay,
    required this.expenseColor,
    required this.symbol,
    required this.useDecimals,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intensity = maxDay > 0 ? (amount / maxDay).clamp(0.0, 1.0) : 0.0;

    final now = DateTime.now();
    final isToday = day == DateTime(now.year, now.month, now.day);

    final cellFill =
        intensity > 0 ? expenseColor.withValues(alpha: 0.15 + intensity * 0.55) : null;
    // Estimating brightness off the actual composited fill, rather than
    // assuming per-theme: light mode's expense red is dark enough for white
    // text, but dark mode's is a much lighter pink where white would lose
    // contrast exactly when the number needs to stand out most.
    final highIntensityTextColor = cellFill != null &&
            ThemeData.estimateBrightnessForColor(
                  Color.alphaBlend(cellFill, theme.colorScheme.surface),
                ) ==
                Brightness.dark
        ? Colors.white
        : AppColors.lightTextPrimary;

    // Tooltip rather than an always-on label: the cell is barely wide enough
    // for the date, and the tap sheet is the real answer.
    return Tooltip(
      message: amount > 0
          ? NumberUtils.formatCurrency(amount, symbol: symbol, useDecimals: useDecimals)
          : '',
      excludeFromSemantics: amount <= 0,
      child: Material(
        color: cellFill ?? Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: isToday
                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: intensity > 0.4
                      ? highIntensityTextColor
                      : theme.textTheme.bodyMedium?.color,
                  fontWeight: intensity > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
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
/// recomputed from the listed transactions rather than read out of the
/// heatmap's own totals, so the two can't disagree.
class _DayTransactionsSheet extends StatelessWidget {
  final DateTime day;

  const _DayTransactionsSheet({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final key = AppDateUtils.formatIso(day);

    // The period list, not allTransactions: the grid only offers days inside
    // the selected period, so this is complete for every day it can open.
    final transactions = context
        .watch<TransactionProvider>()
        .transactions
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
