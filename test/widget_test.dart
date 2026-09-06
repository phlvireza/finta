import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finta/core/theme/app_theme.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/providers/settings_provider.dart';
import 'package:finta/screens/onboarding/onboarding_screen.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(360, 800),
    const Size(412, 915),
    const Size(480, 960),
    const Size(800, 1280),
    const Size(800, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        for (final language in ['en', 'id']) {
          testWidgets(
            'onboarding $size scale=$scale dark=$dark locale=$language',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              await tester.pumpWidget(
                ChangeNotifierProvider(
                  create: (_) => SettingsProvider(),
                  child: MaterialApp(
                    theme: dark ? AppTheme.dark : AppTheme.light,
                    locale: Locale(language),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: const OnboardingScreen(),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              for (var page = 0; page < 4; page++) {
                tester
                    .widget<PageView>(find.byType(PageView))
                    .controller!
                    .jumpToPage(page);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull, reason: 'page $page');
              }
            },
          );
        }
      }
    }
  }
}
