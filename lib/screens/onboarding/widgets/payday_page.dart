import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Onboarding Screen 3 — Payday setup.
class PaydayPage extends StatelessWidget {
  final VoidCallback onComplete;

  const PaydayPage({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context)!;

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
                Icon(
                  Icons.calendar_today,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppConstants.spacingXxl),
                Text(
                  loc.whenDoYouGetPaid,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Text(
                  loc.paydayDescription,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingXxxl),
                // Day selector grid
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingLg),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    // radiusMd, matching the canonical card recipe used
                    // everywhere else — this was the one bordered card in
                    // the app still on radiusLg.
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: 31,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      final isSelected = settings.payday == day;

                      return GestureDetector(
                        onTap: () => settings.setPayday(day),
                        child: AnimatedContainer(
                          duration: AppConstants.animFast,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusSm),
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : null,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXxl),
                SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    onPressed: onComplete,
                    child: Text(loc.startTracking),
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
