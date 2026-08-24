import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/squi.dart';
import '../../core/utils/squi_moments.dart';
import '../../l10n/app_localizations.dart';
import 'squi_illustration.dart';

class SquiMomentSheet extends StatelessWidget {
  final SquiMoment moment;
  final String? name;

  const SquiMomentSheet({super.key, required this.moment, this.name});

  static Future<void> show(
    BuildContext context,
    SquiMoment moment, {
    String? name,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SquiMomentSheet(moment: moment, name: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final (title, body) = switch (moment) {
      SquiMoment.goalReached => (
        loc.squiGoalReachedTitle(name ?? ''),
        loc.squiGoalReachedBody,
      ),
      SquiMoment.debtSettled => (
        loc.squiDebtSettledTitle(name ?? ''),
        loc.squiDebtSettledBody,
      ),
      SquiMoment.firstTransaction => (
        loc.squiFirstTransactionTitle,
        loc.squiFirstTransactionBody,
      ),
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingXxxl,
          AppConstants.spacingSm,
          AppConstants.spacingXxxl,
          AppConstants.spacingXxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SquiIllustration(
              pose: SquiPose.cheer,
              size: SquiSizes.lg,
              animateEntrance: true,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingXl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.squiMomentDismiss),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
