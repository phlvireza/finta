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
import '../../../widgets/section_card.dart';
import '../../../core/utils/category_display.dart';

/// Upcoming section — the next few due recurring transactions, so bills
/// and salary aren't invisible until they're auto-generated. Uses data
/// that already exists (RecurringTransactionModel.nextOccurrence); no
/// new schema or feature needed.
class UpcomingBills extends StatelessWidget {
  const UpcomingBills({super.key});

  @override
  Widget build(BuildContext context) {
    final recurringProvider = context.watch<RecurringProvider>();
    final loc = AppLocalizations.of(context)!;

    final upcoming = recurringProvider.activeRecurring.toList()
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
    final topUpcoming = upcoming.take(AppConstants.upcomingBillsCount).toList();

    if (topUpcoming.isEmpty) return const SizedBox.shrink();

    return SectionCard(
      title: loc.upcoming,
      trailing: upcoming.length > topUpcoming.length
          ? TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecurringListScreen()),
              ),
              child: Text(loc.seeAll),
            )
          : null,
      child: Column(
        children: [
          for (var i = 0; i < topUpcoming.length; i++) ...[
            if (i > 0) const Divider(height: AppConstants.spacingXl),
            _UpcomingItem(template: topUpcoming[i]),
          ],
        ],
      ),
    );
  }
}

class _UpcomingItem extends StatelessWidget {
  final RecurringTransactionModel template;

  const _UpcomingItem({required this.template});

  int _daysUntil(DateTime next) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(next.year, next.month, next.day);
    return date.difference(today).inDays;
  }

  String _dueLabel(AppLocalizations loc, int days, DateTime next) {
    // Was `days <= 0 → dueToday`, which mislabeled anything overdue as
    // merely "due today". Subscriptions already distinguishes the two
    // (_StatusBadge in subscriptions_screen.dart); this brings Upcoming in
    // line so the warning icon below has a real "overdue" state to key off.
    if (days < 0) return loc.overdue;
    if (days == 0) return loc.dueToday;
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

    final days = _daysUntil(template.nextOccurrence);
    final isOverdue = days < 0;
    final dueColor = isOverdue ? AppColors.warning : theme.textTheme.bodySmall?.color;

    return Row(
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
                // Merchant first, same as the Subscriptions list. Leading
                // with the category made every row read as its category
                // ("Bills — due in 3 days"), which names no actual charge.
                Text(
                  template.merchant ??
                      categoryDisplayNameOr(category, loc, fallback: loc.unknown),
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon-plus-warning-color pairing matches the urgency
                    // treatment already used for insight callouts
                    // (insights_hub_screen.dart) — color alone isn't
                    // enough of a signal on its own.
                    if (isOverdue) ...[
                      Icon(Icons.error_outline, size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _dueLabel(loc, days, template.nextOccurrence),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: dueColor,
                        fontWeight: isOverdue ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
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
      );
  }
}
