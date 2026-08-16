import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/account_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/masked_amount.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/form_sheet.dart';
import '../../accounts/manage_accounts_screen.dart';
import '../../accounts/widgets/account_form.dart';

/// "Safe to spend per day" — the single number PocketGuard built its whole
/// value proposition on. Answers "am I on track" without requiring the
/// user to do period-remaining-days math themselves.
///
/// The account strip below it used to be its own net-worth card; folding it
/// in here pairs "what I can spend today" with "where the money actually
/// is", and drops a whole card from the dashboard. Net worth itself lives
/// on Manage Accounts, which already headers that screen with it.
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

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final remainingDays = period.end.difference(todayOnly).inDays + 1;
    final remaining =
        (transactions.totalIncome - transactions.totalExpense).clamp(0, double.infinity);
    final safeToSpendPerDay = remainingDays > 0 ? remaining / remainingDays : 0.0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // A tinted chip showing the user's own currency symbol rather
              // than a generic icon glyph — a hardcoded "$" would be wrong for
              // the large share of this app's audience on IDR.
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: AppConstants.tintAlpha),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  settings.currencySymbol,
                  style: AppTypography.amountStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.safeToSpendLabel, style: theme.textTheme.labelMedium),
                    if (remainingDays > 0)
                      MaskedAmount(
                        text: NumberUtils.formatCurrency(
                          safeToSpendPerDay,
                          symbol: settings.currencySymbol,
                          useDecimals: settings.currencyUseDecimals,
                        ),
                        style: AppTypography.amountStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          const _AccountStrip(),
        ],
      ),
    );
  }
}

/// Horizontally scrollable account balances. Compact by design — this is a
/// glance at where the money sits, not the account manager; tapping any
/// chip goes to [ManageAccountsScreen] for the full view.
class _AccountStrip extends StatelessWidget {
  const _AccountStrip();

  static const double _chipWidth = 120;
  /// Tall enough for the two text lines plus the chip's own padding — the
  /// strip is a fixed-height box because a horizontal ListView has no
  /// intrinsic cross-axis size to fall back on.
  static const double _stripHeight = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final accounts = context.watch<AccountProvider>();
    final settings = context.watch<SettingsProvider>();
    final activeAccounts = accounts.activeAccounts;

    return SizedBox(
      height: _stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: activeAccounts.length + 1,
        separatorBuilder: (context, _) => const SizedBox(width: AppConstants.spacingSm),
        itemBuilder: (context, index) {
          if (index == activeAccounts.length) {
            return _Chip(
              width: 56,
              onTap: () => FormSheet.show(context, builder: (_) => const AccountForm()),
              child: Center(
                child: Tooltip(
                  message: loc.addAccount,
                  child: Icon(Icons.add, size: 20, color: theme.colorScheme.primary),
                ),
              ),
            );
          }

          final account = activeAccounts[index];
          final balance = accounts.balanceOf(account.id);
          // A credit card in use carries a negative balance; showing
          // "-Rp 2.400.000" reads as an error, so it is flipped positive and
          // coloured as debt instead.
          final owed = account.isCreditCard && balance < 0;

          return _Chip(
            width: _chipWidth,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageAccountsScreen()),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  account.name,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                MaskedAmount(
                  text: NumberUtils.formatCurrency(
                    owed ? -balance : balance,
                    symbol: settings.currencySymbol,
                    useDecimals: settings.currencyUseDecimals,
                  ),
                  style: AppTypography.amountStyle(
                    color: owed ? theme.colorScheme.error : theme.colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One outlined mini-card in the strip. Neutral border rather than the
/// account's own colour — a row of five differently tinted boxes competes
/// with the budget rows below it for attention.
class _Chip extends StatelessWidget {
  final double width;
  final VoidCallback onTap;
  final Widget child;

  const _Chip({required this.width, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
