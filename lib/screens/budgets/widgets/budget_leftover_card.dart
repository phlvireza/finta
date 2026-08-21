import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/budget_display.dart';
import '../../../core/utils/budget_entry.dart';
import '../../../core/utils/number_utils.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/masked_amount.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/tinted_icon.dart';
import '../../goals/widgets/contribute_to_goal_sheet.dart';
import '../../transactions/widgets/quick_add_sheet.dart';
import 'budget_category_picker_sheet.dart';
import 'budget_leftover_sheet.dart';
import 'goal_picker_sheet.dart';

/// Prompts the user to decide what happens to the money one-off budgets
/// ended without spending.
///
/// Before this, an ended budget's leftover was invisible: statuses are only
/// built for active budgets, so the money simply stopped being tracked at
/// the period boundary. The card exists to ask the question once, while the
/// user still remembers what the budget was for.
///
/// Each row resolves to one of [BudgetLeftoverAction], or a dismissal.
/// Either way the answer is recorded via `resolveLeftover`, so the prompt
/// never comes back for that budget.
class BudgetLeftoverCard extends StatelessWidget {
  const BudgetLeftoverCard({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final leftovers = context.watch<BudgetProvider>().pendingLeftovers;
    if (leftovers.isEmpty) return const SizedBox.shrink();

    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();

    return SectionCard(
      title: loc.unspentBudgets,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < leftovers.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _LeftoverRow(
              leftover: leftovers[i],
              display: resolveBudgetDisplay(
                budget: leftovers[i].budget,
                categories: categories,
                loc: loc,
                fallbackColor: Theme.of(context).colorScheme.primary,
              ),
              settings: settings,
            ),
          ],
        ],
      ),
    );
  }
}

class _LeftoverRow extends StatelessWidget {
  final BudgetLeftover leftover;
  final ({String title, IconData icon, Color color}) display;
  final SettingsProvider settings;

  const _LeftoverRow({
    required this.leftover,
    required this.display,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final amount = NumberUtils.formatCurrency(
      leftover.leftover,
      symbol: settings.currencySymbol,
      useDecimals: settings.currencyUseDecimals,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Row(
        children: [
          TintedIcon(icon: display.icon, color: display.color, compact: true),
          const SizedBox(width: AppConstants.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display.title,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                MaskedAmount(
                  text: loc.budgetLeftoverSubtitle(amount),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: loc.dismiss,
            onPressed: () => _dismiss(context),
          ),
          FilledButton(
            onPressed: () => _choose(context),
            child: Text(loc.useLeftover),
          ),
        ],
      ),
    );
  }

  Future<void> _dismiss(BuildContext context) async {
    final provider = context.read<BudgetProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context)!;
    try {
      await provider.resolveLeftover(leftover.budget.id);
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(loc.errorFailedToSave)));
    }
  }

  Future<void> _choose(BuildContext context) async {
    final hasGoals = context.read<GoalProvider>().activeGoals.isNotEmpty;
    final action = await BudgetLeftoverSheet.show(
      context,
      canMoveToSavings: hasGoals,
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case BudgetLeftoverAction.rollForward:
        await _rollForward(context);
      case BudgetLeftoverAction.moveToSavings:
        await _moveToSavings(context);
      case BudgetLeftoverAction.markAsSpent:
        await _markAsSpent(context);
    }
  }

  Future<void> _rollForward(BuildContext context) async {
    final provider = context.read<BudgetProvider>();
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context)!;

    try {
      await provider.rollForwardLeftover(leftover, payday: settings.payday);
    } on StateError {
      // The category picked up another budget while this one sat unanswered.
      // Leave the prompt in place: the user may still want to sweep or spend
      // the leftover instead.
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(loc.budgetAlreadyExistsForCategory)),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(loc.errorFailedToSave)));
    }
  }

  Future<void> _moveToSavings(BuildContext context) async {
    final provider = context.read<BudgetProvider>();

    final goal = await GoalPickerSheet.show(context);
    if (goal == null || !context.mounted) return;

    final saved = await ContributeToGoalSheet.show(
      context,
      goal,
      initialAmount: leftover.leftover,
    );
    // Only an actual contribution answers the prompt — backing out of the
    // sheet leaves the question open.
    if (saved) await provider.resolveLeftover(leftover.budget.id);
  }

  Future<void> _markAsSpent(BuildContext context) async {
    final provider = context.read<BudgetProvider>();
    final selectable = context.read<CategoryProvider>().expenseCategories;

    // Same resolution the detail screen's "add expense" uses: a
    // single-category budget prefills, a group budget asks which of its own
    // categories, an overall budget prefills nothing.
    final entry = resolveBudgetEntryCategory(
      budget: leftover.budget,
      selectableCategoryIds: selectable.map((c) => c.id).toSet(),
    );

    var categoryId = entry.categoryId;
    if (entry.choices.isNotEmpty) {
      categoryId = await BudgetCategoryPickerSheet.show(
        context,
        categoryIds: entry.choices,
      );
      if (categoryId == null || !context.mounted) return;
    }
    if (!context.mounted) return;

    final saved = await QuickAddSheet.show(
      context,
      initialCategoryId: categoryId,
      initialAmount: leftover.leftover,
      // The period being settled, not today — an expense dated now would
      // count against the *current* period and leave this budget reading
      // exactly as under-spent as before.
      initialDate: leftover.period.end,
    );
    if (saved) await provider.resolveLeftover(leftover.budget.id);
  }
}
