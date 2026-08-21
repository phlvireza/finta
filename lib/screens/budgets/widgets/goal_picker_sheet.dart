import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/goal_model.dart';
import '../../../providers/goal_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/picker_sheet.dart';
import '../../../widgets/tinted_icon.dart';

/// Picks which savings goal an ended budget's leftover should go toward.
///
/// Only active goals: an archived goal is one the user has finished with,
/// and sweeping money into it would revive it by side effect.
class GoalPickerSheet extends StatelessWidget {
  const GoalPickerSheet({super.key});

  /// Resolves to the chosen goal, or null if the sheet was dismissed.
  static Future<GoalModel?> show(BuildContext context) {
    return PickerSheet.show<GoalModel>(
      context,
      builder: (_) => const GoalPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final goals = context.watch<GoalProvider>().activeGoals;

    return PickerSheet(
      title: loc.selectAGoal,
      children: [
        for (final goal in goals)
          ListTile(
            leading: TintedIcon(
              icon: Icons.savings_outlined,
              color: goal.colorValue,
              compact: true,
            ),
            title: Text(goal.name),
            onTap: () => Navigator.of(context).pop(goal),
          ),
      ],
    );
  }
}
