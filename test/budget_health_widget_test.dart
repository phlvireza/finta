import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finta/core/theme/app_theme.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/models/budget_model.dart';
import 'package:finta/providers/budget_provider.dart';
import 'package:finta/providers/category_provider.dart';
import 'package:finta/providers/settings_provider.dart';
import 'package:finta/screens/budgets/widgets/budget_health_card.dart';
import 'package:finta/screens/budgets/widgets/budget_progress_bar.dart';

class _Budgets extends BudgetProvider {
  final List<BudgetStatus> items;
  _Budgets(this.items);
  @override
  List<BudgetModel> get activeBudgets => items.map((s) => s.budget).toList();
  @override
  Map<String, BudgetStatus> get budgetStatuses => {
    for (final s in items) s.budget.id: s,
  };
}

BudgetStatus _status(String name, double spent, double limit) {
  final now = DateTime.now();
  return BudgetStatus(
    budget: BudgetModel(
      id: name,
      name: name,
      scope: 'overall',
      amount: limit,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
    spent: spent,
    period: (
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    ),
  );
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final dark in [false, true]) {
    for (final locale in ['en', 'id']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('health layout dark=$dark locale=$locale scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final items = [
            _status('Everyday spending', 1250000, 1000000),
            _status('Food and groceries', 800000, 1000000),
            _status('Weekend plans', 100000, 800000),
          ];
          final budgets = _Budgets(items);
          final settings = SettingsProvider();
          addTearDown(budgets.dispose);
          addTearDown(settings.dispose);
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => CategoryProvider()),
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: scale == 2,
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: ColoredBox(
                        color: dark
                            ? AppTheme.dark.scaffoldBackgroundColor
                            : AppTheme.light.scaffoldBackgroundColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              BudgetHealthCard(
                                budgetProvider: budgets,
                                settings: settings,
                              ),
                              const SizedBox(height: 24),
                              BudgetProgressBar(
                                status: items.first,
                                symbol: 'Rp',
                                useDecimals: false,
                              ),
                              BudgetProgressBar(
                                status: _status('Empty limit', 0, 0),
                                symbol: 'Rp',
                                useDecimals: false,
                              ),
                              BudgetProgressBar(
                                status: _status('Limit reached', 100, 100),
                                symbol: 'Rp',
                                useDecimals: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.textContaining('125%'), findsNWidgets(2));
          final progress = tester.widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(progress.every((p) => p.value! >= 0 && p.value! <= 1), isTrue);
          if (locale == 'en') {
            expect(find.text('No available budget'), findsOneWidget);
            expect(find.text('Limit reached'), findsNWidgets(2));
          }
          // Optional rendered artifacts for local visual review, never baseline updates.
          if (Platform.environment['BUDGET_PREVIEW'] == '1' &&
              scale == 1 &&
              locale == 'en') {
            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final picture = await boundary.toImage(pixelRatio: 1);
              final bytes = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory('build/budget-preview');
              await directory.create(recursive: true);
              await File(
                '${directory.path}/${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              picture.dispose();
            });
          }
        });
      }
    }
  }
}
