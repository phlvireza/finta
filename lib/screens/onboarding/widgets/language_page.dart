import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Onboarding Screen 1 — Language selection.
///
/// First rather than later on purpose: every page after this one is text, so
/// the choice has to land before the user has to read anything. The list is
/// pre-selected from the device language by [SettingsProvider], so for most
/// users this is a confirmation rather than a decision.
class LanguagePage extends StatelessWidget {
  final VoidCallback onNext;

  const LanguagePage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context)!;

    // Language names are shown in their own language, never translated — a
    // language picker only works if a user who cannot read the current locale
    // can still spot their own.
    final languages = [
      (code: 'en', flag: '🇺🇸', name: loc.languageNameEnglish),
      (code: 'id', flag: '🇮🇩', name: loc.languageNameIndonesian),
    ];

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
                  Icons.translate,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppConstants.spacingXxl),
                Text(
                  loc.chooseYourLanguage,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Text(
                  loc.languageChangeableLater,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingXxxl),
                ...languages.map((language) {
                  final isSelected = settings.languageCode == language.code;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await settings.setLanguage(language.code);
                          // SettingsProvider cannot reach CategoryProvider, so
                          // the caller pairs the two.
                          if (!context.mounted) return;
                          await context
                              .read<CategoryProvider>()
                              .localizeDefaultNames(language.code);
                        },
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        child: AnimatedContainer(
                          duration: AppConstants.animFast,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingLg,
                            vertical: AppConstants.spacingMd,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                language.flag,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: AppConstants.spacingMd),
                              Expanded(
                                child: Text(
                                  language.name,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppConstants.spacingXxl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onNext,
                    child: Text(loc.continueLabel),
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
