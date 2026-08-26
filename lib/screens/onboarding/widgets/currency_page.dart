import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Onboarding Screen 2 — Currency selection.
class CurrencyPage extends StatelessWidget {
  final VoidCallback onNext;

  const CurrencyPage({super.key, required this.onNext});

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
                  Icons.currency_exchange,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: AppConstants.spacingXxl),
                Text(
                  loc.chooseYourCurrency,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Text(
                  loc.currencyDisplayOnly,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spacingXxxl),
                ...AppConstants.currencies.map((currency) {
                  final isSelected = settings.currencyCode == currency.code;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => settings.setCurrency(currency.code),
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
                              SizedBox(
                                width: 36,
                                child: Text(
                                  currency.symbol,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppConstants.spacingMd),
                              Expanded(
                                child: Text(
                                  currency.name,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                              Text(
                                currency.code,
                                style: theme.textTheme.bodySmall,
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: AppConstants.spacingSm),
                                Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
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
                  height: AppConstants.buttonHeight,
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
