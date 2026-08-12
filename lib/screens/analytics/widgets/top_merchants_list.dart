import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/merchant_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/empty_state.dart';
import '../../transactions/widgets/transaction_tile.dart';

/// Ranked merchant spend for the period the analytics screen is showing.
///
/// Lives here rather than inside the trends report so there is exactly one
/// merchant list in the app: the old copy was pinned to a hardcoded
/// three-month window that ignored the period selector, which meant the
/// screen answered a different question than the one its header implied.
class TopMerchantsList extends StatelessWidget {
  final List<MerchantAnalytics> data;
  final String symbol;
  final bool useDecimals;

  /// The window [data] was aggregated over, handed to the drill-down so it
  /// lists exactly the transactions behind the total that was tapped.
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  /// Which side of the ledger these totals came from, so the drill-down
  /// doesn't mix a refund into a spending list.
  final bool isIncome;

  const TopMerchantsList({
    super.key,
    required this.data,
    required this.symbol,
    required this.useDecimals,
    required this.rangeStart,
    required this.rangeEnd,
    required this.isIncome,
  });

  void _openMerchant(BuildContext context, MerchantAnalytics merchant) {
    final start = rangeStart;
    final end = rangeEnd;
    if (start == null || end == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MerchantTransactionsSheet(
        merchant: merchant,
        start: start,
        end: end,
        isIncome: isIncome,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final palette = isDark ? AppColors.chartColorsDark : AppColors.chartColorsLight;

    if (data.isEmpty) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        title: loc.noMerchantsForThisPeriod,
        subtitle: '',
      );
    }

    return Column(
      children: [
        for (var i = 0; i < data.length; i++)
          InkWell(
            onTap: () => _openMerchant(context, data[i]),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingSm,
                vertical: AppConstants.spacingSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette[i % palette.length].withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette[i % palette.length],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data[i].merchant, style: theme.textTheme.titleSmall),
                        Text(loc.timesCount(data[i].count), style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                  Text(
                    NumberUtils.formatCurrency(
                      data[i].total,
                      symbol: symbol,
                      useDecimals: useDecimals,
                    ),
                    style: AppTypography.amountStyle(
                      color: theme.textTheme.bodyLarge!.color!,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The transactions behind one merchant row.
///
/// Filters the already-loaded transaction list rather than issuing a query:
/// the rank list is built from a period-scoped aggregate, and re-deriving the
/// same rows through a second code path is how the header total and the list
/// underneath it drift apart. Matching is on [normalizeMerchant] so the rows
/// folded into the total are exactly the rows listed here.
class MerchantTransactionsSheet extends StatelessWidget {
  final MerchantAnalytics merchant;
  final DateTime start;
  final DateTime end;
  final bool isIncome;

  const MerchantTransactionsSheet({
    super.key,
    required this.merchant,
    required this.start,
    required this.end,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    final transactions = context.watch<TransactionProvider>().allTransactions.where((t) {
      if (t.isTransfer || t.isIncome != isIncome) return false;
      if (!hasMerchant(t.merchant)) return false;
      if (normalizeMerchant(t.merchant!) != merchant.key) return false;
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      return !day.isBefore(startDay) && !day.isAfter(endDay);
    }).toList();

    final total = transactions.fold<double>(0, (sum, t) => sum + t.amount);

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
                        Text(merchant.merchant, style: theme.textTheme.titleLarge),
                        Text(loc.timesCount(transactions.length),
                            style: theme.textTheme.labelMedium),
                      ],
                    ),
                  ),
                  Text(
                    NumberUtils.formatCurrency(
                      total,
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
                      title: loc.noDataForThisPeriod,
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
