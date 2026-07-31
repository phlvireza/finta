import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/utils/date_utils.dart';

/// App-bar period navigation — lets the user step the dashboard back to
/// past payday periods and forward again, instead of being locked to
/// whatever period is "current" right now.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          child: Text(
            AppDateUtils.formatPeriodRange(period.start, period.end),
            style: theme.textTheme.headlineSmall,
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
