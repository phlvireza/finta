import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/confirm_dialog.dart';
import '../add_transaction_screen.dart';

/// Reusable tile for displaying a single transaction. Used on both the
/// dashboard (dense: true) and the full history screen (dense: false) so
/// the two never drift apart the way the dashboard's old inline row did.
class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final bool dense;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.watch<CategoryProvider>();
    final accounts = context.watch<AccountProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    final category = categories.getCategoryById(transaction.categoryId);
    final account = accounts.getAccountById(transaction.accountId);
    final isIncome = transaction.isIncome;
    final amountColor = isIncome
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

    final iconBoxSize = dense ? 40.0 : 48.0;
    final iconSize = dense ? 20.0 : 24.0;
    final titleStyle = dense ? theme.textTheme.titleSmall : theme.textTheme.titleMedium;
    final amountFontSize = dense ? 14.0 : 15.0;
    final recurringIconSize = dense ? 12.0 : 14.0;

    final hasMerchant = !transaction.isTransfer &&
        transaction.merchant != null &&
        transaction.merchant!.isNotEmpty;
    final title = transaction.isTransfer
        ? loc.transfer
        : (hasMerchant ? transaction.merchant! : (category?.name ?? loc.unknown));
    final subtitleParts = <String>[
      // Merchant takes the title slot, so the category becomes part of the
      // subtitle instead of being redundant with it.
      if (hasMerchant) (category?.name ?? loc.unknown),
      if (account != null) account.name,
      if (transaction.note != null && transaction.note!.isNotEmpty) transaction.note!,
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ??
            () {
              if (transaction.isTransfer) {
                _showTransferDetails(context);
                return;
              }
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  editTransaction: transaction,
                ),
              ));
            },
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: AppConstants.spacingMd,
            horizontal: dense ? 0 : AppConstants.spacingLg,
          ),
          child: Row(
            children: [
              // Category icon
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: (category?.colorValue ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    dense ? AppConstants.radiusSm : AppConstants.radiusMd,
                  ),
                ),
                child: Icon(
                  transaction.isTransfer
                      ? Icons.swap_horiz
                      : (category?.iconData ?? Icons.category),
                  size: iconSize,
                  color: category?.colorValue ?? theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              // Name and note
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: titleStyle,
                    ),
                    if (subtitleParts.isNotEmpty)
                      Text(
                        subtitleParts.join(' · '),
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'} ${NumberUtils.formatCurrency(
                      transaction.amount,
                      symbol: settings.currencySymbol,
                      useDecimals: settings.currencyUseDecimals,
                    )}',
                    style: AppTypography.amountStyle(
                      color: amountColor,
                      fontSize: amountFontSize,
                    ),
                  ),
                  if (transaction.isRecurring)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.repeat,
                        size: recurringIconSize,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Transfer legs can't be opened in [AddTransactionScreen] — editing just
  /// one side would desync the pair — so tapping one shows a small detail
  /// sheet with a delete action (which removes both legs together).
  void _showTransferDetails(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final accounts = context.read<AccountProvider>();
    final settings = context.read<SettingsProvider>();
    final isOut = transaction.isExpense;
    final account = accounts.getAccountById(transaction.accountId);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.transfer, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                isOut
                    ? loc.transferOutOf(account?.name ?? loc.unknown)
                    : loc.transferIntoAccount(account?.name ?? loc.unknown),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                NumberUtils.formatCurrency(
                  transaction.amount,
                  symbol: settings.currencySymbol,
                  useDecimals: settings.currencyUseDecimals,
                ),
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: AppConstants.spacingXl),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(loc.deleteTransfer),
                  onPressed: () async {
                    final confirmed = await ConfirmDialog.show(
                      sheetContext,
                      title: loc.deleteTransfer,
                      message: loc.confirmDeleteTransfer,
                    );
                    if (confirmed && sheetContext.mounted) {
                      await sheetContext.read<TransactionProvider>().deleteTransaction(transaction.id);
                      if (sheetContext.mounted) {
                        await sheetContext.read<AccountProvider>().loadAccounts();
                      }
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
