import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';

/// "Safe to spend per day" — the single number PocketGuard built its whole
/// value proposition on. Answers "am I on track" without requiring the
/// user to do period-remaining-days math themselves.
class BurnRateIndicator extends StatelessWidget {
  const BurnRateIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final period = transactions.period;
    if (period == null) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context)!;
    final income = transactions.totalIncome;
    final expense = transactions.totalExpense;
    final spentRatio = income > 0 ? (expense / income).clamp(0.0, 1.0) : 0.0;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final remainingDays = period.end.difference(todayOnly).inDays + 1;
    final remaining = (income - expense).clamp(0, double.infinity);
    final safeToSpendPerDay = remainingDays > 0 ? remaining / remainingDays : 0.0;

    final isDark = theme.brightness == Brightness.dark;
    final barColor = spentRatio >= 1.0
        ? (isDark ? AppColors.darkExpense : AppColors.lightExpense)
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          child: LinearProgressIndicator(
            value: spentRatio,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          loc.percentOfIncomeSpent(NumberUtils.formatPercentage(spentRatio)),
          style: theme.textTheme.labelSmall,
        ),
        if (remainingDays > 0) ...[
          const SizedBox(height: 2),
          Text(
            loc.safeToSpendPerDay(
              NumberUtils.formatCurrency(
                safeToSpendPerDay,
                symbol: settings.currencySymbol,
                useDecimals: settings.currencyUseDecimals,
              ),
              remainingDays,
            ),
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
