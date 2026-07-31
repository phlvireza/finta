import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/number_utils.dart';
import '../../core/utils/subscription_detector.dart';
import '../../models/recurring_transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/empty_state.dart';
import '../../l10n/app_localizations.dart';

/// Lists tracked subscriptions with their combined monthly/annual cost and
/// upcoming-charge badges, and surfaces auto-detected candidates — merchants
/// with a regular near-monthly, near-identical-amount pattern — that aren't
/// tracked as a recurring template yet.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final Set<String> _dismissedSuggestions = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final recurringProvider = context.watch<RecurringProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    final subscriptions = recurringProvider.subscriptions;
    final monthlyTotal = subscriptions.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);

    final trackedMerchants = recurringProvider.activeRecurring
        .map((r) => r.merchant)
        .whereType<String>()
        .toSet();
    final candidates = detectSubscriptionCandidates(
      transactionProvider.allTransactions,
      excludeMerchants: trackedMerchants,
    ).where((c) => !_dismissedSuggestions.contains(c.merchant)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(loc.subscriptions)),
      body: (subscriptions.isEmpty && candidates.isEmpty)
          ? EmptyState(
              icon: Icons.subscriptions_outlined,
              title: loc.noSubscriptionsTitle,
              subtitle: loc.noSubscriptionsSubtitle,
            )
          : ListView(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              children: [
                if (subscriptions.isNotEmpty) ...[
                  _CostSummaryCard(
                    monthlyTotal: monthlyTotal,
                    symbol: settings.currencySymbol,
                    useDecimals: settings.currencyUseDecimals,
                  ),
                  const SizedBox(height: AppConstants.spacingXxl),
                ],
                if (candidates.isNotEmpty) ...[
                  Text(loc.subscriptionSuggestions, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppConstants.spacingMd),
                  ...candidates.map((c) => _SuggestionTile(
                        candidate: c,
                        symbol: settings.currencySymbol,
                        useDecimals: settings.currencyUseDecimals,
                        onAdd: () => _addSuggestion(context, c),
                        onDismiss: () => setState(() => _dismissedSuggestions.add(c.merchant)),
                      )),
                  const SizedBox(height: AppConstants.spacingXxl),
                ],
                if (subscriptions.isNotEmpty) ...[
                  Text(loc.yourSubscriptions, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppConstants.spacingMd),
                  ...subscriptions.map((s) => _SubscriptionTile(
                        subscription: s,
                        categoryProvider: categoryProvider,
                        settings: settings,
                      )),
                ],
              ],
            ),
    );
  }

  Future<void> _addSuggestion(BuildContext context, SubscriptionCandidate c) async {
    final recurringProvider = context.read<RecurringProvider>();
    await recurringProvider.addRecurring(
      type: 'expense',
      amount: c.amount,
      categoryId: c.categoryId,
      accountId: c.accountId,
      merchant: c.merchant,
      frequency: 'monthly',
      startDate: c.predictedNextDate,
      isSubscription: true,
    );
    if (context.mounted) {
      setState(() => _dismissedSuggestions.add(c.merchant));
    }
  }
}

class _CostSummaryCard extends StatelessWidget {
  final double monthlyTotal;
  final String symbol;
  final bool useDecimals;

  const _CostSummaryCard({
    required this.monthlyTotal,
    required this.symbol,
    required this.useDecimals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.perMonth, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  NumberUtils.formatCurrency(monthlyTotal, symbol: symbol, useDecimals: useDecimals),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: theme.colorScheme.outline),
          const SizedBox(width: AppConstants.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.perYear, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  NumberUtils.formatCurrency(monthlyTotal * 12, symbol: symbol, useDecimals: useDecimals),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final SubscriptionCandidate candidate;
  final String symbol;
  final bool useDecimals;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  const _SuggestionTile({
    required this.candidate,
    required this.symbol,
    required this.useDecimals,
    required this.onAdd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate.merchant, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    loc.subscriptionSuggestionSubtitle(
                      NumberUtils.formatCurrency(candidate.amount, symbol: symbol, useDecimals: useDecimals),
                      candidate.occurrenceCount,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: loc.dismiss,
              onPressed: onDismiss,
            ),
            FilledButton(onPressed: onAdd, child: Text(loc.add)),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final RecurringTransactionModel subscription;
  final CategoryProvider categoryProvider;
  final SettingsProvider settings;

  const _SubscriptionTile({
    required this.subscription,
    required this.categoryProvider,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final category = categoryProvider.getCategoryById(subscription.categoryId);
    final name = subscription.merchant ?? category?.name ?? loc.unknown;
    final daysUntil = subscription.nextOccurrence
        .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
        .inDays;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (category?.colorValue ?? theme.colorScheme.primary).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          child: Icon(category?.iconData ?? Icons.subscriptions, color: category?.colorValue ?? theme.colorScheme.primary),
        ),
        title: Text(name, style: theme.textTheme.titleMedium),
        subtitle: Row(
          children: [
            Text(
              subscription.frequencyLabel,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: AppConstants.spacingSm),
            _StatusBadge(subscription: subscription, daysUntil: daysUntil),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              NumberUtils.formatCurrency(
                subscription.amount,
                symbol: settings.currencySymbol,
                useDecimals: settings.currencyUseDecimals,
              ),
              style: theme.textTheme.titleMedium,
            ),
            _SubscriptionMenu(subscription: subscription),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final RecurringTransactionModel subscription;
  final int daysUntil;

  const _StatusBadge({required this.subscription, required this.daysUntil});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    if (subscription.isPaused) {
      return _badge(theme, loc.paused, theme.colorScheme.outline);
    }

    final soon = daysUntil <= (subscription.reminderDaysBefore ?? 3);
    final color = daysUntil < 0 || soon ? AppColors.warning : theme.colorScheme.primary;
    final label = daysUntil < 0
        ? loc.overdue
        : daysUntil == 0
            ? loc.dueToday
            : loc.dueInDays(daysUntil);
    return _badge(theme, label, color);
  }

  Widget _badge(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SubscriptionMenu extends StatelessWidget {
  final RecurringTransactionModel subscription;

  const _SubscriptionMenu({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      onSelected: (value) => _handle(context, value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: subscription.isPaused ? 'resume' : 'pause',
          child: Text(subscription.isPaused ? loc.resume : loc.pause),
        ),
        PopupMenuItem(value: 'reminder', child: Text(loc.setReminder)),
        PopupMenuItem(value: 'untrack', child: Text(loc.notASubscription)),
      ],
    );
  }

  Future<void> _handle(BuildContext context, String action) async {
    final provider = context.read<RecurringProvider>();
    switch (action) {
      case 'pause':
        await provider.pauseSubscription(subscription.id);
        break;
      case 'resume':
        await provider.resumeSubscription(subscription.id);
        break;
      case 'untrack':
        await provider.setIsSubscription(subscription.id, false);
        break;
      case 'reminder':
        await _pickReminder(context);
        break;
    }
  }

  Future<void> _pickReminder(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final choice = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(loc.setReminder),
        children: [
          _reminderOption(dialogContext, null, loc.reminderOff),
          _reminderOption(dialogContext, 1, loc.reminderDaysBeforeOption(1)),
          _reminderOption(dialogContext, 2, loc.reminderDaysBeforeOption(2)),
          _reminderOption(dialogContext, 3, loc.reminderDaysBeforeOption(3)),
          _reminderOption(dialogContext, 7, loc.reminderDaysBeforeOption(7)),
        ],
      ),
    );
    if (choice == -1 || !context.mounted) return;
    await context.read<RecurringProvider>().setReminderDaysBefore(subscription.id, choice);
  }

  Widget _reminderOption(BuildContext context, int? value, String label) {
    final isSelected = subscription.reminderDaysBefore == value;
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(value ?? -1),
      child: Row(
        children: [
          if (isSelected) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
          const SizedBox(width: AppConstants.spacingSm),
          Text(label),
        ],
      ),
    );
  }
}
