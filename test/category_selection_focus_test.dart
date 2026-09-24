import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:finta/core/constants/app_constants.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/models/account_model.dart';
import 'package:finta/models/category_model.dart';
import 'package:finta/providers/account_provider.dart';
import 'package:finta/providers/category_provider.dart';
import 'package:finta/providers/settings_provider.dart';
import 'package:finta/providers/template_provider.dart';
import 'package:finta/providers/transaction_provider.dart';
import 'package:finta/repositories/category_repository.dart';
import 'package:finta/screens/transactions/add_transaction_screen.dart';
import 'package:finta/screens/transactions/widgets/category_picker.dart';
import 'package:finta/screens/transactions/widgets/merchant_field.dart';
import 'package:finta/screens/transactions/widgets/quick_add_sheet.dart';

class _Categories extends CategoryRepository {
  @override
  Future<List<CategoryModel>> getAll() async => [
    CategoryModel(
      id: 'food',
      name: 'Food & Drinks',
      type: 'expense',
      icon: 'restaurant',
      color: '#3F8B4C',
      isDefault: true,
      sortOrder: 0,
      createdAt: DateTime(2026),
    ),
  ];
}

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

void main() {
  setUpAll(initializeDateFormatting);

  for (final quick in [true, false]) {
    testWidgets(
      'category search selection focuses Note in ${quick ? 'quick add' : 'full form'}',
      (tester) async {
        tester.view.physicalSize = const Size(480, 960);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final categories = CategoryProvider(repository: _Categories());
        await categories.loadCategories();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
              ChangeNotifierProvider<AccountProvider>(
                create: (_) => _Accounts(),
              ),
              ChangeNotifierProvider<CategoryProvider>.value(value: categories),
              ChangeNotifierProvider(create: (_) => TransactionProvider()),
              ChangeNotifierProvider(create: (_) => TemplateProvider()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: quick
                  ? const Scaffold(body: QuickAddSheet())
                  : const AddTransactionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final merchant = find.descendant(
          of: find.byType(MerchantField),
          matching: find.byType(TextField),
        );
        await tester.ensureVisible(merchant);
        await tester.tap(merchant);
        await tester.pump();
        expect(tester.widget<TextField>(merchant).focusNode!.hasFocus, isTrue);

        await tester.ensureVisible(find.byType(CategoryPicker));
        await tester.tap(find.text('Select a category...').first);
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(CategoryPicker))).pop();
        await tester.pumpAndSettle();
        final note = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.maxLength == AppConstants.maxNoteLength,
        );
        expect(tester.widget<TextField>(note).focusNode!.hasFocus, isFalse);

        await tester.tap(find.text('Select a category...').first);
        await tester.pumpAndSettle();
        final search = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Search categories...',
        );
        await tester.enterText(search, 'Food');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Food & Drinks').last);
        await tester.pumpAndSettle();

        expect(tester.widget<TextField>(note).focusNode!.hasFocus, isTrue);
        expect(tester.widget<TextField>(merchant).focusNode!.hasFocus, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
