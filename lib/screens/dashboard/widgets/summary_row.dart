import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/constants/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/masked_amount.dart';

/// Summary row — income and expense totals side by side.
class SummaryRow extends StatelessWidget {
  const SummaryRow({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();

    final loc = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: loc.income,
            amount: transactions.totalIncome,
            // Compared against the SAME dashboard period, not whatever
            // period the Analytics screen happens to have selected.
            previousAmount: transactions.previousTotalIncome,
            symbol: settings.currencySymbol,
            useDecimals: settings.currencyUseDecimals,
            isIncome: true,
          ),
        ),
        const SizedBox(width: AppConstants.spacingMd),
        Expanded(
          child: _SummaryCard(
            label: loc.expense,
            amount: transactions.totalExpense,
            previousAmount: transactions.previousTotalExpense,
            symbol: settings.currencySymbol,
            useDecimals: settings.currencyUseDecimals,
            isIncome: false,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final double previousAmount;
  final String symbol;
  final bool useDecimals;
  final bool isIncome;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.previousAmount,
    required this.symbol,
    required this.useDecimals,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accentColor = isIncome
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                label,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          MaskedAmount(
            text: NumberUtils.formatCurrency(
              amount,
              symbol: symbol,
              useDecimals: useDecimals,
            ),
            style: AppTypography.amountStyle(
              color: accentColor,
              fontSize: 17,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (previousAmount > 0) ...[
            const SizedBox(height: 4),
            _buildComparisonText(theme),
          ]
        ],
      ),
    );
  }

  Widget _buildComparisonText(ThemeData theme) {
    final diff = amount - previousAmount;
    final percent = (diff.abs() / previousAmount) * 100;
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

    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          '${percent.toStringAsFixed(0)}% vs last',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
