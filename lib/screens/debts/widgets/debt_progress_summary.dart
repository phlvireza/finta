import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/debt_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
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

  /// Money you lent out reads as the app's income green (it's coming back),
  /// money you borrowed reads as its expense rose — the same semantic pair
  /// used everywhere else, rather than Material's generic green/red.
  /// Exposed so the debt list and the detail screen can tint other chrome
  /// to match.
  static Color colorFor(DebtModel debt, bool isDark) =>
      debt.isLent ? colorForLent(isDark) : colorForBorrowed(isDark);

  static Color colorForLent(bool isDark) => isDark ? AppColors.darkIncome : AppColors.lightIncome;
  static Color colorForBorrowed(bool isDark) => isDark ? AppColors.darkExpense : AppColors.lightExpense;

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
    final isDark = theme.brightness == Brightness.dark;
    final color = colorFor(debt, isDark);

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
