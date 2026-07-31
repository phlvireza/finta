import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/constants/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/masked_amount.dart';
import '../../accounts/manage_accounts_screen.dart';
import '../../accounts/widgets/account_form.dart';

/// Net worth summary plus a horizontally scrollable account carousel —
/// sits above [BalanceCard] on the dashboard so "how much do I have"
/// (net worth, across every account) is answered before "how did this
/// period go" (the period net).
class NetWorthCard extends StatelessWidget {
  const NetWorthCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final accounts = context.watch<AccountProvider>();
    final settings = context.watch<SettingsProvider>();
    final activeAccounts = accounts.activeAccounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(loc.netWorth, style: theme.textTheme.labelMedium),
            GestureDetector(
              onTap: () => settings.setHideBalances(!settings.hideBalances),
              child: Icon(
                settings.hideBalances ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingXs),
        MaskedAmount(
          text: NumberUtils.formatCurrency(
            accounts.netWorth,
            symbol: settings.currencySymbol,
            useDecimals: settings.currencyUseDecimals,
          ),
          style: AppTypography.amountStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppConstants.spacingLg),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: activeAccounts.length + 1,
            separatorBuilder: (context, _) => const SizedBox(width: AppConstants.spacingMd),
            itemBuilder: (context, index) {
              if (index == activeAccounts.length) {
                return _AddAccountCard(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AccountForm(),
                  ),
                );
              }
              final account = activeAccounts[index];
              final balance = accounts.balanceOf(account.id);
              final owed = account.isCreditCard && balance < 0;

              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageAccountsScreen()),
                ),
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: account.colorValue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: account.colorValue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(account.iconData, color: account.colorValue, size: 20),
                      Text(
                        account.name,
                        style: theme.textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      MaskedAmount(
                        text: NumberUtils.formatCurrency(
                          owed ? -balance : balance,
                          symbol: settings.currencySymbol,
                          useDecimals: settings.currencyUseDecimals,
                        ),
                        style: AppTypography.amountStyle(
                          color: owed
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddAccountCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddAccountCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: theme.colorScheme.outline,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: theme.colorScheme.primary),
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              loc.addAccount,
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
