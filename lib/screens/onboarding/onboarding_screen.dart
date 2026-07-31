import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import 'widgets/welcome_page.dart';
import 'widgets/currency_page.dart';
import 'widgets/payday_page.dart';
import '../../l10n/app_localizations.dart';

/// Onboarding screen — 3-page PageView shown on first launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: AppConstants.animNormal,
        curve: Curves.easeOut,
      );
    }
  }

  void _complete() {
    context.read<SettingsProvider>().completeOnboarding();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingLg),
                child: TextButton(
                  onPressed: _complete,
                  child: Text(
                    AppLocalizations.of(context)!.skip,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                  ),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  WelcomePage(onNext: _nextPage),
                  CurrencyPage(onNext: _nextPage),
                  PaydayPage(onComplete: _complete),
                ],
              ),
            ),
            // Page indicator
            Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingXxxl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: AppConstants.animFast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
