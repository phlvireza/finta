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
import 'package:finta/screens/budgets/manage_budgets_screen.dart';
import 'package:finta/screens/budgets/widgets/budget_pace_bar.dart';
import 'package:finta/widgets/squi/squi_illustration.dart';

class _Budgets extends BudgetProvider {
  final List<BudgetStatus> items;
  final List<BudgetModel> endedItems;

  _Budgets(this.items, {this.endedItems = const []});

  @override
  List<BudgetModel> get activeBudgets =>
      items.map((status) => status.budget).toList();

  @override
  Map<String, BudgetStatus> get budgetStatuses => {
    for (final status in items) status.budget.id: status,
  };

  @override
  List<BudgetModel> get endedBudgets => endedItems;
}

BudgetStatus status(
  String id, {
  required String name,
  required String cadence,
  required double budgeted,
  required double spent,
  double rollover = 0,
}) {
  final start = DateTime(2026, 9, cadence == 'weekly' ? 7 : 1);
  return BudgetStatus(
    budget: BudgetModel(
      id: id,
      name: name,
      amount: budgeted,
      period: cadence,
      scope: 'overall',
      isActive: true,
      createdAt: start,
      updatedAt: start,
    ),
    spent: spent,
    rolloverAmount: rollover,
    period: (
      start: start,
      end: cadence == 'weekly'
          ? start.add(const Duration(days: 6))
          : DateTime(2026, 9, 30),
    ),
  );
}

BudgetModel endedBudget(
  String id, {
  required String name,
  required String cadence,
}) {
  final createdAt = DateTime(2026, 8, cadence == 'weekly' ? 24 : 1);
  return BudgetModel(
    id: id,
    name: name,
    amount: 100000,
    period: cadence,
    scope: 'overall',
    isActive: false,
    isRecurring: false,
    createdAt: createdAt,
    updatedAt: cadence == 'weekly'
        ? createdAt.add(const Duration(days: 6))
        : DateTime(2026, 8, 31),
  );
}

Future<void> captureBudgetPreview(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  if (Platform.environment['BUDGET_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/budget-preview/cadence-selector');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

const _summaryMetricKeys = [
  ValueKey('budget-summary-budgeted-metric'),
  ValueKey('budget-summary-spent-metric'),
  ValueKey('budget-summary-remaining-metric'),
];

void expectSummaryAmountsOnOneLine(WidgetTester tester) {
  for (final key in _summaryMetricKeys) {
    final amount = find
        .descendant(of: find.byKey(key), matching: find.byType(Text))
        .last;
    final paragraph = tester.renderObject<RenderParagraph>(amount);
    expect(paragraph.maxLines, 1, reason: '$key should be limited to one line');
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '$key should not clip or ellipsize its exact value',
    );
  }
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
    for (final scale in [1.0, 2.0]) {
      testWidgets('budget overview adapts dark=$dark scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final budgets = _Budgets([
          status(
            'monthly',
            name: 'A very long monthly household budget name',
            cadence: 'monthly',
            budgeted: 1000000,
            spent: 650000,
          ),
          status(
            'weekly',
            name: 'Weekly essentials',
            cadence: 'weekly',
            budgeted: 250000,
            spent: 325000,
          ),
        ]);
        final settings = SettingsProvider();
        final categories = CategoryProvider();
        final previewKey = GlobalKey();
        addTearDown(budgets.dispose);
        addTearDown(settings.dispose);
        addTearDown(categories.dispose);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<CategoryProvider>.value(value: categories),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: scale == 2,
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: previewKey,
                child: const ManageBudgetsScreen(embedded: true),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('budget-cadence-selector')),
          findsOneWidget,
        );
        expect(find.text('Left this period'), findsOneWidget);
        expect(find.text('Total budget usage'), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('budget-total-usage-label')),
              )
              .data,
          '65% used',
        );
        var totalProgress = tester.widget<BudgetPaceBar>(
          find.byKey(const ValueKey('budget-total-progress')),
        );
        expect(totalProgress.ratio, 0.65);
        expect(
          totalProgress.barColor,
          (dark ? AppTheme.dark : AppTheme.light).colorScheme.primary,
        );
        expectSummaryAmountsOnOneLine(tester);
        final metricWidth = tester
            .getSize(find.byKey(_summaryMetricKeys.first))
            .width;
        expect(metricWidth, scale == 1 ? lessThan(120) : greaterThan(250));
        if (!dark && scale == 1) {
          await captureBudgetPreview(
            tester,
            previewKey,
            'monthly-within-light',
          );
        }
        if (!dark && scale == 2) {
          await captureBudgetPreview(
            tester,
            previewKey,
            'monthly-within-light-large-text',
          );
        }
        await tester.dragUntilVisible(
          find.text('Budget versus spending'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        expect(find.text('Budget versus spending'), findsOneWidget);
        await tester.dragUntilVisible(
          find.text('Weekly'),
          find.byType(ListView),
          const Offset(0, 200),
        );
        expect(find.text('Weekly essentials'), findsNothing);

        await tester.tap(find.text('Weekly'));
        await tester.pumpAndSettle();

        expect(find.text('Over budget by'), findsOneWidget);
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('budget-total-usage-label')),
              )
              .data,
          '130% used',
        );
        totalProgress = tester.widget<BudgetPaceBar>(
          find.byKey(const ValueKey('budget-total-progress')),
        );
        expect(totalProgress.ratio, 1.3);
        expect(
          totalProgress.barColor,
          (dark ? AppTheme.dark : AppTheme.light).colorScheme.error,
        );
        if (dark && scale == 1) {
          await captureBudgetPreview(
            tester,
            previewKey,
            'weekly-overspent-dark',
          );
        }

        await tester.dragUntilVisible(
          find.text('Weekly essentials').first,
          find.byType(ListView),
          const Offset(0, -200),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Weekly essentials'), findsWidgets);
        expect(
          find.text('A very long monthly household budget name'),
          findsNothing,
        );
      });
    }
  }

  testWidgets('hides financial values and only shows available cadence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final budgets = _Budgets([
      status(
        'monthly',
        name: 'Belanja rumah tangga',
        cadence: 'monthly',
        budgeted: 1000000,
        spent: 250000,
      ),
    ]);
    final settings = SettingsProvider();
    await settings.setHideBalances(true);
    final categories = CategoryProvider();
    final previewKey = GlobalKey();
    addTearDown(budgets.dispose);
    addTearDown(settings.dispose);
    addTearDown(categories.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CategoryProvider>.value(value: categories),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RepaintBoundary(
            key: previewKey,
            child: const ManageBudgetsScreen(embedded: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Anggaran dibanding pengeluaran'), findsOneWidget);
    expect(find.textContaining('Rp'), findsNothing);
    expect(find.byKey(const ValueKey('budget-cadence-selector')), findsNothing);
    expect(find.textContaining('Bulanan · 1 anggaran aktif'), findsOneWidget);
    expect(find.text('Mingguan'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('budget-total-usage-label')))
          .data,
      '25% terpakai',
    );
    await captureBudgetPreview(tester, previewKey, 'hidden-balances-light');
    expect(tester.takeException(), isNull);
  });

  for (final fixture in [
    (
      name: 'monthly-only overview uses context instead of a selector',
      cadence: 'monthly',
      locale: const Locale('en'),
      dark: false,
      scale: 1.0,
      expectedContext: 'Monthly · 1 active budget',
      absentCadence: 'Weekly',
      preview: 'monthly-only-light',
    ),
    (
      name: 'weekly-only overview uses context at large text',
      cadence: 'weekly',
      locale: const Locale('id'),
      dark: true,
      scale: 2.0,
      expectedContext: 'Mingguan · 1 anggaran aktif',
      absentCadence: 'Bulanan',
      preview: 'weekly-only-dark-large-text',
    ),
  ]) {
    testWidgets(fixture.name, (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final budgets = _Budgets([
        status(
          'only-cadence',
          name: 'Essentials',
          cadence: fixture.cadence,
          budgeted: 1000000,
          spent: 450000,
        ),
      ]);
      final settings = SettingsProvider();
      final categories = CategoryProvider();
      final previewKey = GlobalKey();
      addTearDown(budgets.dispose);
      addTearDown(settings.dispose);
      addTearDown(categories.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<CategoryProvider>.value(value: categories),
          ],
          child: MaterialApp(
            theme: fixture.dark ? AppTheme.dark : AppTheme.light,
            locale: fixture.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(fixture.scale),
                disableAnimations: fixture.scale == 2,
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: previewKey,
              child: const ManageBudgetsScreen(embedded: true),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('budget-cadence-selector')),
        findsNothing,
      );
      expect(find.textContaining(fixture.expectedContext), findsOneWidget);
      expect(find.text(fixture.absentCadence), findsNothing);
      await captureBudgetPreview(tester, previewKey, fixture.preview);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ended cadence keeps the two-way selector discoverable', (
    tester,
  ) async {
    final budgets = _Budgets(
      [
        status(
          'monthly-active',
          name: 'Monthly active',
          cadence: 'monthly',
          budgeted: 1000000,
          spent: 250000,
        ),
      ],
      endedItems: [
        endedBudget('weekly-ended', name: 'Weekly archive', cadence: 'weekly'),
      ],
    );
    final settings = SettingsProvider();
    final categories = CategoryProvider();
    addTearDown(budgets.dispose);
    addTearDown(settings.dispose);
    addTearDown(categories.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CategoryProvider>.value(value: categories),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ManageBudgetsScreen(embedded: true),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('budget-cadence-selector')),
      findsOneWidget,
    );
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(find.text('Squi is waiting for a weekly budget'), findsOneWidget);
    expect(find.text('Weekly archive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one ended cadence has context without a one-item selector', (
    tester,
  ) async {
    final budgets = _Budgets(
      const [],
      endedItems: [
        endedBudget('weekly-ended', name: 'Weekly archive', cadence: 'weekly'),
      ],
    );
    final settings = SettingsProvider();
    final categories = CategoryProvider();
    addTearDown(budgets.dispose);
    addTearDown(settings.dispose);
    addTearDown(categories.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CategoryProvider>.value(value: categories),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ManageBudgetsScreen(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('budget-cadence-selector')), findsNothing);
    expect(find.text('Squi is waiting for a weekly budget'), findsOneWidget);
    expect(find.text('Weekly archive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final fixture in [
    (
      name: 'long IDR values stay exact in a wider light layout',
      size: const Size(320, 900),
      locale: const Locale('id'),
      currency: 'IDR',
      dark: false,
      budgeted: 987654321012.0,
      spent: 123456789012.0,
      preview: 'long-idr-light',
    ),
    (
      name: 'long decimal values stay exact in a wider dark layout',
      size: const Size(360, 900),
      locale: const Locale('en'),
      currency: 'USD',
      dark: true,
      budgeted: 1234567890.12,
      spent: 2345678901.23,
      preview: 'long-usd-overspent-dark',
    ),
  ]) {
    testWidgets(fixture.name, (tester) async {
      tester.view.physicalSize = fixture.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final budgets = _Budgets([
        status(
          'long-values',
          name: 'Long value budget',
          cadence: 'monthly',
          budgeted: fixture.budgeted,
          spent: fixture.spent,
        ),
      ]);
      final settings = SettingsProvider();
      await settings.setCurrency(fixture.currency);
      final categories = CategoryProvider();
      final previewKey = GlobalKey();
      addTearDown(budgets.dispose);
      addTearDown(settings.dispose);
      addTearDown(categories.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<CategoryProvider>.value(value: categories),
          ],
          child: MaterialApp(
            theme: fixture.dark ? AppTheme.dark : AppTheme.light,
            locale: fixture.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: previewKey,
              child: const ManageBudgetsScreen(embedded: true),
            ),
          ),
        ),
      );
      await tester.pump();

      expectSummaryAmountsOnOneLine(tester);
      final metricSizes = _summaryMetricKeys
          .map((key) => tester.getSize(find.byKey(key)))
          .toList();
      expect(
        metricSizes.every((size) => size.width > fixture.size.width * 0.7),
        isTrue,
      );
      final metricTops = _summaryMetricKeys
          .map((key) => tester.getTopLeft(find.byKey(key)).dy)
          .toSet();
      expect(metricTops, hasLength(3));
      await captureBudgetPreview(tester, previewKey, fixture.preview);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('global empty state uses Squi voice at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final budgets = _Budgets([]);
    final settings = SettingsProvider();
    final categories = CategoryProvider();
    addTearDown(budgets.dispose);
    addTearDown(settings.dispose);
    addTearDown(categories.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CategoryProvider>.value(value: categories),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const ManageBudgetsScreen(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Squi is waiting for your first budget'), findsOneWidget);
    expect(find.byType(SquiIllustration), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-positive effective total omits percentage and pace marker', (
    tester,
  ) async {
    final budgets = _Budgets([
      status(
        'depleted',
        name: 'Depleted rollover',
        cadence: 'monthly',
        budgeted: 100,
        spent: 10,
        rollover: -100,
      ),
    ]);
    final settings = SettingsProvider();
    final categories = CategoryProvider();
    addTearDown(budgets.dispose);
    addTearDown(settings.dispose);
    addTearDown(categories.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CategoryProvider>.value(value: categories),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ManageBudgetsScreen(embedded: true),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('budget-total-usage-label')),
      findsNothing,
    );
    final progress = tester.widget<BudgetPaceBar>(
      find.byKey(const ValueKey('budget-total-progress')),
    );
    expect(progress.ratio, 1);
    expect(progress.showPaceMarker, isFalse);
    expect(progress.barColor, AppTheme.light.colorScheme.error);
    expect(tester.takeException(), isNull);
  });
}
