import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/picker_sheet.dart';

/// What the user chose to do with an ended budget's unspent money.
///
/// Dismissing is not in here: it's a one-tap action on the card itself, so
/// the sheet only carries the choices that actually do something.
enum BudgetLeftoverAction { rollForward, moveToSavings, markAsSpent }

/// Asks what should happen to the money a one-off budget didn't spend.
///
/// Ordered by how little damage each option does. Rolling forward is first
/// because it changes no money at all — it just re-budgets it. Moving to
/// savings moves real money but keeps it the user's. Marking as spent is
/// last and deliberately so: it books an expense for money that was never
/// actually spent, which is the only option here that costs the user
/// anything on paper.
class BudgetLeftoverSheet extends StatelessWidget {
  /// False when the user has no active goals to sweep into — offering
  /// "move to savings" would open a picker with nothing in it.
  final bool canMoveToSavings;

  const BudgetLeftoverSheet({super.key, required this.canMoveToSavings});

  /// Resolves to the chosen action, or null if the sheet was dismissed.
  static Future<BudgetLeftoverAction?> show(
    BuildContext context, {
    required bool canMoveToSavings,
  }) {
    return PickerSheet.show<BudgetLeftoverAction>(
      context,
      builder: (_) => BudgetLeftoverSheet(canMoveToSavings: canMoveToSavings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PickerSheet(
      title: loc.budgetLeftoverTitle,
      children: [
        ListTile(
          leading: Icon(Icons.refresh, color: theme.colorScheme.primary),
          title: Text(loc.rollForwardBudget),
          subtitle: Text(loc.rollForwardBudgetDesc),
          onTap: () =>
              Navigator.of(context).pop(BudgetLeftoverAction.rollForward),
        ),
        if (canMoveToSavings)
          ListTile(
            leading: Icon(Icons.savings_outlined, color: theme.colorScheme.primary),
            title: Text(loc.moveLeftoverToSavings),
            subtitle: Text(loc.moveLeftoverToSavingsDesc),
            onTap: () =>
                Navigator.of(context).pop(BudgetLeftoverAction.moveToSavings),
          ),
        ListTile(
          leading: Icon(Icons.remove_circle_outline, color: theme.colorScheme.primary),
          title: Text(loc.markLeftoverAsSpent),
          subtitle: Text(loc.markLeftoverAsSpentDesc),
          onTap: () =>
              Navigator.of(context).pop(BudgetLeftoverAction.markAsSpent),
        ),
      ],
    );
  }
}
