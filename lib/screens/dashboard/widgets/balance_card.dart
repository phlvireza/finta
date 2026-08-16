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

/// Balance card — the period's net, prominently at the top of the
/// dashboard, with income and expense folded in below a hairline divider.
/// The period itself (and navigating between periods) is shown in the app
/// bar's PeriodSelector, so this card doesn't repeat the date range.
///
/// Income/expense used to be a separate card below this one
/// (`SummaryRow`); merging them here removes a whole undecorated section
/// from the dashboard without dropping any of the numbers it showed,
/// including the "vs last period" comparison.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context)!;
    final onPrimary = theme.colorScheme.onPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingXxl),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.netThisPeriod,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onPrimary.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          MaskedAmount(
            text: NumberUtils.formatCurrency(
              transactions.balance,
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
            ),
            style: AppTypography.amountStyle(
              color: onPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Container(
            height: 1,
            color: onPrimary.withValues(alpha: 0.22),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Row(
            children: [
              Expanded(
                child: _InlineStat(
                  label: loc.income,
                  amount: transactions.totalIncome,
                  previousAmount: transactions.previousTotalIncome,
                  settings: settings,
                  loc: loc,
                  isIncome: true,
                  onPrimary: onPrimary,
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: onPrimary.withValues(alpha: 0.22),
                margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              ),
              Expanded(
                child: _InlineStat(
                  label: loc.expense,
                  amount: transactions.totalExpense,
                  previousAmount: transactions.previousTotalExpense,
                  settings: settings,
                  loc: loc,
                  isIncome: false,
                  onPrimary: onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String label;
  final double amount;
  final double previousAmount;
  final SettingsProvider settings;
  final AppLocalizations loc;
  final bool isIncome;
  final Color onPrimary;

  const _InlineStat({
    required this.label,
    required this.amount,
    required this.previousAmount,
    required this.settings,
    required this.loc,
    required this.isIncome,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: onPrimary.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        MaskedAmount(
          text: NumberUtils.formatCurrency(
            amount,
            symbol: settings.currencySymbol,
            useDecimals: settings.currencyUseDecimals,
          ),
          style: AppTypography.amountStyle(color: onPrimary, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (previousAmount > 0) ...[
          const SizedBox(height: 2),
          _buildComparison(theme),
        ],
      ],
    );
  }

  Widget _buildComparison(ThemeData theme) {
    final diff = amount - previousAmount;
    final percent = (diff.abs() / previousAmount) * 100;
    final isMore = diff > 0;

    // Up is only "good" for income; for expense it flips. Both cases still
    // resolve against AppColors rather than the primary-tinted card
    // background, so the comparison keeps reading as income/expense colour
    // coding even while it sits on the hero card.
    final isDark = theme.brightness == Brightness.dark;
    final good = isIncome ? isMore : !isMore;
    final color = good
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);
    // Blended toward onPrimary so the semantic colour stays legible against
    // the solid primary fill instead of clashing with it.
    final displayColor = Color.lerp(color, onPrimary, 0.35)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMore ? Icons.arrow_upward : Icons.arrow_downward,
          size: 11,
          color: displayColor,
        ),
        const SizedBox(width: 2),
        Text(
          loc.percentVsLast(percent.toStringAsFixed(0)),
          style: theme.textTheme.labelSmall?.copyWith(color: displayColor, fontSize: 11),
        ),
      ],
    );
  }
}
