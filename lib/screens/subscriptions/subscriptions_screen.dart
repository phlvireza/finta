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
import '../../widgets/squi/squi_state.dart';
import '../../core/constants/squi.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_card.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/tinted_icon.dart';
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
    final loc = AppLocalizations.of(context)!;
    final recurringProvider = context.watch<RecurringProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    final subscriptions = recurringProvider.subscriptions;
    final monthlyTotal = subscriptions.fold(
      0.0,
      (sum, s) => sum + s.monthlyEquivalent,
    );

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
          ? SquiState(
              pose: SquiPose.rest,
              title: loc.squiQuietSubscriptions,
              subtitle: loc.squiQuietSubscriptionsBody,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.fabClearance,
              ),
              children: [
                if (subscriptions.isNotEmpty) ...[
                  _CostSummaryCard(
                    monthlyTotal: monthlyTotal,
                    symbol: settings.currencySymbol,
                    useDecimals: settings.currencyUseDecimals,
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
                if (candidates.isNotEmpty) ...[
                  SectionCard(
                    title: loc.subscriptionSuggestions,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final c in candidates) ...[
                          if (c != candidates.first) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(
                              AppConstants.spacingMd,
                            ),
                            child: _SuggestionTile(
                              candidate: c,
                              symbol: settings.currencySymbol,
                              useDecimals: settings.currencyUseDecimals,
                              onAdd: () => _addSuggestion(context, c),
                              onDismiss: () => setState(
                                () => _dismissedSuggestions.add(c.merchant),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
                if (subscriptions.isNotEmpty)
                  SectionCard(
                    title: loc.yourSubscriptions,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final s in subscriptions) ...[
                          if (s != subscriptions.first)
                            const Divider(height: 1),
                          _SubscriptionTile(
                            subscription: s,
                            categoryProvider: categoryProvider,
                            settings: settings,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _addSuggestion(
    BuildContext context,
    SubscriptionCandidate c,
  ) async {
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
    return SectionCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.perMonth, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  NumberUtils.formatCurrency(
                    monthlyTotal,
                    symbol: symbol,
                    useDecimals: useDecimals,
                  ),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                  NumberUtils.formatCurrency(
                    monthlyTotal * 12,
                    symbol: symbol,
                    useDecimals: useDecimals,
                  ),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(candidate.merchant, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                loc.subscriptionSuggestionSubtitle(
                  NumberUtils.formatCurrency(
                    candidate.amount,
                    symbol: symbol,
                    useDecimals: useDecimals,
                  ),
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
        .difference(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ),
        )
        .inDays;

    // Deliberately not a ListTile. ListTile hands `trailing` whatever width
    // it asks for and squeezes the title column with the remainder, so an
    // amount plus a 48px overflow menu left the subtitle no room and the
    // "Overdue" badge ran straight into the amount. Laying the row out
    // directly keeps the gap under our control, and the Wrap lets the badge
    // drop to its own line rather than collide on narrow screens.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingMd,
        AppConstants.spacingSm,
        AppConstants.spacingMd,
      ),
      child: Row(
        children: [
          TintedIcon(
            icon: category?.iconData ?? Icons.subscriptions,
            color: category?.colorValue ?? theme.colorScheme.primary,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: AppConstants.spacingSm,
                  runSpacing: AppConstants.spacingXs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      subscription.frequencyLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                    _StatusBadge(
                      subscription: subscription,
                      daysUntil: daysUntil,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Text(
            NumberUtils.formatCurrency(
              subscription.amount,
              symbol: settings.currencySymbol,
              useDecimals: settings.currencyUseDecimals,
            ),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(width: AppConstants.spacingXs),
          _SubscriptionMenu(subscription: subscription),
        ],
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
      return StatusPill(label: loc.paused, color: theme.colorScheme.outline);
    }

    final soon = daysUntil <= (subscription.reminderDaysBefore ?? 3);
    final color = daysUntil < 0 || soon
        ? AppColors.warning
        : theme.colorScheme.primary;
    final label = daysUntil < 0
        ? loc.overdue
        : daysUntil == 0
        ? loc.dueToday
        : loc.dueInDays(daysUntil);
    return StatusPill(label: label, color: color);
  }
}

class _SubscriptionMenu extends StatelessWidget {
  final RecurringTransactionModel subscription;

  const _SubscriptionMenu({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      // The default 48px tap target is width the amount next to it needs
      // more than the menu does.
      padding: EdgeInsets.zero,
      onSelected: (value) => _handle(context, value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: subscription.isPaused ? 'resume' : 'pause',
          child: Text(subscription.isPaused ? loc.resume : loc.pause),
        ),
        PopupMenuItem(value: 'reminder', child: Text(loc.setReminder)),
        PopupMenuItem(value: 'untrack', child: Text(loc.notASubscription)),
        PopupMenuItem(
          value: 'cancel',
          child: Text(
            loc.cancelSubscription,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
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
        // Deliberately not a cancel: the schedule keeps running and keeps
        // posting charges, it just stops being listed here.
        await provider.setIsSubscription(subscription.id, false);
        break;
      case 'cancel':
        await _cancel(context);
        break;
      case 'reminder':
        await _pickReminder(context);
        break;
    }
  }

  /// Ends the subscription for good — the same stop as the Recurring
  /// screen's delete, which is what "cancelled my Netflix" means. Untracking
  /// only hides it from this list, so without this the screen had no way to
  /// stop a charge that has actually stopped in real life.
  Future<void> _cancel(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.cancelSubscription,
      message: loc.cancelSubscriptionMessage,
      confirmText: loc.stop,
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final recurring = context.read<RecurringProvider>();
    final transactions = context.read<TransactionProvider>();
    final settings = context.read<SettingsProvider>();
    try {
      await recurring.deleteRecurring(subscription.id);
      // The stop unlinks the charges it already posted, so they stop drawing
      // the repeat badge — both cached lists still hold the old copies.
      await transactions.loadTransactions(payday: settings.payday);
      await transactions.loadAllTransactions();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(loc.subscriptionCancelled)));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(loc.errorFailedToDelete)));
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
    await context.read<RecurringProvider>().setReminderDaysBefore(
      subscription.id,
      choice,
    );
  }

  Widget _reminderOption(BuildContext context, int? value, String label) {
    final isSelected = subscription.reminderDaysBefore == value;
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(value ?? -1),
      child: Row(
        children: [
          if (isSelected)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: AppConstants.spacingSm),
          Text(label),
        ],
      ),
    );
  }
}
