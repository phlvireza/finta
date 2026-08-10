import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';

/// Toggle switch and frequency dropdown for recurring transactions.
class RecurringToggle extends StatelessWidget {
  final bool isRecurring;
  final ValueChanged<bool> onToggle;
  final String frequency;
  final ValueChanged<String> onFrequencyChanged;
  final bool isSubscription;
  final ValueChanged<bool> onSubscriptionToggle;

  const RecurringToggle({
    super.key,
    required this.isRecurring,
    required this.onToggle,
    required this.frequency,
    required this.onFrequencyChanged,
    required this.isSubscription,
    required this.onSubscriptionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loc.makeThisRecurring,
              style: theme.textTheme.titleMedium,
            ),
            Switch(
              value: isRecurring,
              onChanged: onToggle,
            ),
          ],
        ),
        if (isRecurring) ...[
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            loc.frequency,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
              vertical: 4, // Dropdown has internal padding
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: frequency,
                isExpanded: true,
                onChanged: (val) {
                  if (val != null) onFrequencyChanged(val);
                },
                items: [
                  DropdownMenuItem(value: 'daily', child: Text(loc.daily)),
                  DropdownMenuItem(value: 'weekly', child: Text(loc.weekly)),
                  DropdownMenuItem(value: 'biweekly', child: Text(loc.biweekly)),
                  DropdownMenuItem(value: 'monthly', child: Text(loc.monthly)),
                  DropdownMenuItem(value: 'yearly', child: Text(loc.yearly)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(loc.markAsSubscription, style: theme.textTheme.titleMedium),
                  const SizedBox(width: AppConstants.spacingSm),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    onTap: () => _showSubscriptionInfo(context, loc),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary.withAlpha(180),
                      ),
                    ),
                  ),
                ],
              ),
              Switch(
                value: isSubscription,
                onChanged: onSubscriptionToggle,
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showSubscriptionInfo(BuildContext context, AppLocalizations loc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.subscriptions),
        content: Text(loc.markAsSubscriptionHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.gotIt),
          ),
        ],
      ),
    );
  }
}
