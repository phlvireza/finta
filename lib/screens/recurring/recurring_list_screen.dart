import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/number_utils.dart';
import '../../core/utils/date_utils.dart';
import '../../core/constants/app_typography.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/confirm_dialog.dart';
import '../transactions/add_transaction_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../l10n/app_localizations.dart';

/// Screen to view and manage active recurring transactions.
class RecurringListScreen extends StatelessWidget {
  const RecurringListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recurringProvider = context.watch<RecurringProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;

    final templates = recurringProvider.activeRecurring;

    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.recurringTransactions),
      ),
      body: templates.isEmpty
          ? EmptyState(
              icon: Icons.repeat,
              title: loc.noRecurringTransactions,
              subtitle: loc.enableRecurringWhenAdding,
              action: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(),
                    fullscreenDialog: true,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(loc.createFirstRecurring),
              ),
            )
          : ListView.builder(
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final category = categories.getCategoryById(template.categoryId);

                final isIncome = template.isIncome;
                final amountColor = isIncome
                    ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
                    : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

                return Slidable(
                  key: ValueKey(template.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.25,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _deleteTemplate(context, template.id),
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        icon: Icons.delete,
                        label: loc.delete,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.colorScheme.outline),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacingMd,
                      horizontal: AppConstants.spacingLg,
                    ),
                    child: Row(
                      children: [
                        // Category icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (category?.colorValue ?? theme.colorScheme.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          ),
                          child: Icon(
                            category?.iconData ?? Icons.category,
                            size: 24,
                            color: category?.colorValue ?? theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingMd),
                        // Name, Note, Frequency
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category?.name ?? loc.unknown,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (template.note != null && template.note!.isNotEmpty)
                                Text(
                                  template.note!,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 2),
                              Text(
                                '${template.frequencyLabel} • ${loc.next}: ${AppDateUtils.formatFull(template.nextOccurrence)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Amount
                        Text(
                          '${isIncome ? '+' : '-'} ${NumberUtils.formatCurrency(
                            template.amount,
                            symbol: settings.currencySymbol,
                            useDecimals: settings.currencyUseDecimals,
                          )}',
                          style: AppTypography.amountStyle(
                            color: amountColor,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _deleteTemplate(BuildContext context, String id) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.stopRecurring,
      message: loc.stopRecurringMessage,
      confirmText: loc.stop,
    );

    if (confirmed && context.mounted) {
      try {
        await context.read<RecurringProvider>().deleteRecurring(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.errorFailedToDelete)),
          );
        }
      }
    }
  }
}
