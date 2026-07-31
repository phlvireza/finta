import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/utils/number_utils.dart';
import '../models/transaction_model.dart';

/// Header for a date-grouped transaction list, showing the group's net
/// total alongside the date label so a day's activity doesn't have to be
/// added up by eye. Shared by the dashboard's recent list and the full
/// history screen so both stay in sync.
class DateGroupHeader extends StatelessWidget {
  final String label;
  final List<TransactionModel> transactions;

  const DateGroupHeader({
    super.key,
    required this.label,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;

    final net = transactions.fold<double>(
      0,
      (sum, t) => sum + (t.isIncome ? t.amount : -t.amount),
    );
    final color = net >= 0
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Text(
            '${net >= 0 ? '+' : '-'} ${NumberUtils.formatCurrency(
              net.abs(),
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
            )}',
            style: AppTypography.amountStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
