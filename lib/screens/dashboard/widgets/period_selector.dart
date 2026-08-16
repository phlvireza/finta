import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';

/// App-bar period navigation — lets the user step the dashboard back to
/// past payday periods and forward again, instead of being locked to
/// whatever period is "current" right now.
///
/// The range sits above a small caption naming the period as "Current pay
/// period" — otherwise the payday-anchored cycle, the app's headline
/// difference from a calendar-month tracker, is never actually named
/// anywhere in the UI.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final transactions = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final period = transactions.period;

    if (period == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
          onPressed: transactions.isLoading
              ? null
              : () => transactions.goToPreviousPeriod(payday: settings.payday),
        ),
        GestureDetector(
          onTap: transactions.isViewingCurrentPeriod
              ? null
              : () => transactions.resetToCurrentPeriod(payday: settings.payday),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                AppDateUtils.formatPeriodRange(period.start, period.end),
                style: theme.textTheme.titleLarge,
              ),
              if (transactions.isViewingCurrentPeriod)
                Text(loc.currentPayPeriod, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
          onPressed: transactions.isLoading || transactions.isViewingCurrentPeriod
              ? null
              : () => transactions.goToNextPeriod(payday: settings.payday),
        ),
      ],
    );
  }
}
