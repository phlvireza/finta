import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/recurring_provider.dart';
import '../../../models/recurring_transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../recurring/recurring_list_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Upcoming section — the next few due recurring transactions, so bills
/// and salary aren't invisible until they're auto-generated. Uses data
/// that already exists (RecurringTransactionModel.nextOccurrence); no
/// new schema or feature needed.
class UpcomingBills extends StatelessWidget {
  const UpcomingBills({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recurringProvider = context.watch<RecurringProvider>();
    final loc = AppLocalizations.of(context)!;

    final upcoming = recurringProvider.activeRecurring.toList()
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
    final topUpcoming = upcoming.take(AppConstants.upcomingBillsCount).toList();

    if (topUpcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(loc.upcoming, style: theme.textTheme.titleLarge),
            if (upcoming.length > topUpcoming.length)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecurringListScreen()),
                ),
                child: Text(loc.seeAll),
              ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingSm),
        ...topUpcoming.map((template) => _UpcomingItem(template: template)),
      ],
    );
  }
}

class _UpcomingItem extends StatelessWidget {
  final RecurringTransactionModel template;

  const _UpcomingItem({required this.template});

  String _dueLabel(AppLocalizations loc, DateTime next) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(next.year, next.month, next.day);
    final days = date.difference(today).inDays;
    if (days <= 0) return loc.dueToday;
    if (days == 1) return loc.dueTomorrow;
    if (days < 7) return loc.dueInDays(days);
    return AppDateUtils.formatFull(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    final category = categories.getCategoryById(template.categoryId);
    final isIncome = template.isIncome;
    final amountColor = isIncome
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (category?.colorValue ?? theme.colorScheme.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(
              category?.iconData ?? Icons.repeat,
              size: 20,
              color: category?.colorValue ?? theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category?.name ?? loc.unknown, style: theme.textTheme.titleSmall),
                Text(
                  _dueLabel(loc, template.nextOccurrence),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'} ${NumberUtils.formatCurrency(
              template.amount,
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
            )}',
            style: AppTypography.amountStyle(color: amountColor, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
