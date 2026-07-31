import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/constants/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/masked_amount.dart';

/// Balance card — displays the net for the currently loaded period,
/// prominently at the top of the dashboard. The period itself (and
/// navigating between periods) is shown in the app bar's PeriodSelector,
/// so this card doesn't repeat the date range.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactions = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.netThisPeriod,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                onTap: () => settings.setHideBalances(!settings.hideBalances),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingXs),
                  child: Icon(
                    settings.hideBalances ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          MaskedAmount(
            text: NumberUtils.formatCurrency(
              transactions.balance,
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
            ),
            style: AppTypography.amountStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
