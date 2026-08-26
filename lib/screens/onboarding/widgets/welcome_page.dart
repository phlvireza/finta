import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/constants/squi.dart';
import '../../../widgets/squi/squi_illustration.dart';

/// Onboarding Screen 1 — Welcome page with tagline.
class WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const WelcomePage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXxxl),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppConstants.maxContentWidth,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SquiIllustration(pose: SquiPose.wave, size: SquiSizes.lg),
                const SizedBox(height: AppConstants.spacingXxxl),
                Text(
                  'Squirio',
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 40,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Text(
                  AppLocalizations.of(context)!.trackYourMoney,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingXxxl * 2),
                SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    onPressed: onNext,
                    child: Text(AppLocalizations.of(context)!.getStarted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
