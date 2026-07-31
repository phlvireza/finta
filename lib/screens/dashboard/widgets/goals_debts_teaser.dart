import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../goals/goals_list_screen.dart';
import '../../debts/debts_list_screen.dart';

/// Compact dashboard teaser for goals and debts — shows the single
/// nearest-to-complete active goal and the net debt summary, so both
/// features stay visible without dedicating a full dashboard section to
/// each. Hides itself entirely when there's nothing to show, same as
/// UpcomingBills.
class GoalsDebtsTeaser extends StatelessWidget {
  const GoalsDebtsTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    final goalProvider = context.watch<GoalProvider>();
    final debtProvider = context.watch<DebtProvider>();
    final goals = goalProvider.activeGoals;
    final hasDebts = debtProvider.activeDebts.isNotEmpty;

    if (goals.isEmpty && !hasDebts) return const SizedBox.shrink();

    final topGoal = goals.isEmpty
        ? null
        : (goals.toList()..sort((a, b) {
            final ra = a.targetAmount <= 0 ? 1.0 : goalProvider.progressOf(a.id) / a.targetAmount;
            final rb = b.targetAmount <= 0 ? 1.0 : goalProvider.progressOf(b.id) / b.targetAmount;
            return rb.compareTo(ra);
          })).first;

    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.goalsAndDebts, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppConstants.spacingSm),
        if (topGoal != null)
          InkWell(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GoalsListScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
              child: Row(
                children: [
                  Icon(Icons.savings_outlined, color: topGoal.colorValue, size: 20),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(child: Text(topGoal.name, style: theme.textTheme.bodyMedium)),
                  Text(
                    NumberUtils.formatPercentage(
                      topGoal.targetAmount <= 0
                          ? 1
                          : (goalProvider.progressOf(topGoal.id) / topGoal.targetAmount).clamp(0.0, 1.0),
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        if (hasDebts)
          InkWell(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DebtsListScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined, size: 20),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Text(
                      loc.netDebtSummary(
                        NumberUtils.formatCurrency(debtProvider.totalOwedToMe, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
                        NumberUtils.formatCurrency(debtProvider.totalIOwe, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
