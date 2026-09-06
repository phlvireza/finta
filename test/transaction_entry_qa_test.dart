import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:finta/core/theme/app_theme.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/models/account_model.dart';
import 'package:finta/providers/account_provider.dart';
import 'package:finta/providers/category_provider.dart';
import 'package:finta/providers/insights_provider.dart';
import 'package:finta/providers/settings_provider.dart';
import 'package:finta/providers/template_provider.dart';
import 'package:finta/providers/transaction_provider.dart';
import 'package:finta/screens/transactions/add_transaction_screen.dart';
import 'package:finta/screens/transactions/widgets/quick_add_sheet.dart';
import 'package:finta/screens/transactions/widgets/category_picker.dart';
import 'package:finta/widgets/amount_input_field.dart';

class _Accounts extends AccountProvider {
  @override
  List<AccountModel> get activeAccounts => [
    AccountModel(
      id: 'cash',
      name: 'Cash',
      type: 'cash',
      openingBalance: 0,
      color: '#C87941',
      sortOrder: 0,
      createdAt: DateTime(2026),
    ),
  ];
}

class _Insights extends InsightsProvider {
  int checks = 0;
  final pending = Completer<({bool isAnomaly, double mean})?>();
  @override
  Future<({bool isAnomaly, double mean})?> checkAnomaly(
    String categoryId,
    double amount,
  ) {
    checks++;
    return pending.future;
  }
}

void main() {
  setUpAll(initializeDateFormatting);
  for (final quick in [true, false]) {
    for (final dark in [false, true]) {
      testWidgets(
        'entry quick=$quick dark=$dark prevents concurrent saves and recovers from lookup failure',
        (tester) async {
          tester.view.physicalSize = const Size(412, 915);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final insights = _Insights();
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => SettingsProvider()),
                ChangeNotifierProvider<AccountProvider>(
                  create: (_) => _Accounts(),
                ),
                ChangeNotifierProvider(create: (_) => CategoryProvider()),
                ChangeNotifierProvider(create: (_) => TransactionProvider()),
                ChangeNotifierProvider(create: (_) => TemplateProvider()),
                ChangeNotifierProvider<InsightsProvider>.value(value: insights),
              ],
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: quick
                    ? const Scaffold(
                        body: QuickAddSheet(
                          initialCategoryId: 'food',
                          initialAmount: 100,
                        ),
                      )
                    : const AddTransactionScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (!quick) {
            tester
                    .widget<AmountInputField>(find.byType(AmountInputField))
                    .controller
                    .text =
                '100';
            tester
                .widget<CategoryPicker>(find.byType(CategoryPicker))
                .onCategorySelected('food');
            await tester.pump();
          }
          final save = tester
              .widget<ElevatedButton>(find.byType(ElevatedButton).last)
              .onPressed!;
          save();
          save();
          await tester.pump();
          expect(insights.checks, 1);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          insights.pending.completeError(
            StateError('simulated lookup failure'),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byType(ElevatedButton), findsWidgets);
          await tester.pumpWidget(const SizedBox());
          insights.dispose();
        },
      );
    }
  }
}
