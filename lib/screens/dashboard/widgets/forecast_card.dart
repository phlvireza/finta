import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/forecast_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';

/// "Projected [period] spend" — extrapolates the current period's burn
/// rate to its end, the same underlying math as [BurnRateIndicator]'s
/// safe-to-spend figure, just projected forward instead of divided across
/// remaining days. Colored as a warning once the projection would exceed
/// income, folding naturally into the same at-a-glance overspend signal
/// the budget cards already use.
class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final period = transactions.period;
    if (period == null) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context)!;
    final projected = projectEndOfPeriod(
      spentSoFar: transactions.totalExpense,
      periodStart: period.start,
      periodEnd: period.end,
    );

    final isDark = theme.brightness == Brightness.dark;
    final overIncome = transactions.totalIncome > 0 && projected > transactions.totalIncome;
    final color = overIncome
        ? (isDark ? AppColors.darkExpense : AppColors.lightExpense)
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, color: color),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.projectedSpendLabel(AppDateUtils.formatMonthYear(period.start)),
                  style: theme.textTheme.labelMedium,
                ),
                Text(
                  NumberUtils.formatCurrency(
                    projected,
                    symbol: settings.currencySymbol,
                    useDecimals: settings.currencyUseDecimals,
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
