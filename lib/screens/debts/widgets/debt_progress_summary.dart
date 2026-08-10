import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/debt_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';

/// The progress bar, outstanding-of-principal line and due date for one debt.
///
/// Shared by the debt card and the debt detail screen so the two can never
/// disagree about what is still owed — the detail screen exists to show the
/// repayments *behind* the number the card shows, and a second copy of this
/// arithmetic would be the easiest way for those to drift apart.
class DebtProgressSummary extends StatelessWidget {
  final DebtModel debt;

  /// Money you lent out reads green (it's coming back), money you borrowed
  /// reads red. Exposed so the detail screen can tint other chrome to match.
  static Color colorFor(DebtModel debt) => debt.isLent ? Colors.green : Colors.redAccent;

  const DebtProgressSummary({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<DebtProvider>();
    final outstanding = provider.outstandingOf(debt);
    final settled = provider.isSettled(debt);
    final ratio = debt.principal <= 0 ? 1.0 : (1 - outstanding / debt.principal).clamp(0.0, 1.0);
    final color = colorFor(debt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        if (settled)
          Text(loc.debtSettled, style: theme.textTheme.bodySmall?.copyWith(color: color))
        else
          Text(
            loc.debtOutstandingOfPrincipal(
              NumberUtils.formatCurrency(outstanding, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
              NumberUtils.formatCurrency(debt.principal, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
            ),
            style: theme.textTheme.bodySmall,
          ),
        if (debt.dueDate != null && !settled) ...[
          const SizedBox(height: 2),
          Text(
            loc.debtDueDate(AppDateUtils.formatFull(debt.dueDate!)),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
