import 'package:finta/core/constants/app_constants.dart';
import 'package:finta/core/theme/app_theme.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/models/account_model.dart';
import 'package:finta/providers/account_provider.dart';
import 'package:finta/providers/settings_provider.dart';
import 'package:finta/screens/accounts/widgets/account_form.dart';
import 'package:finta/widgets/amount_keypad.dart';
import 'package:finta/widgets/keypad_amount_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Accounts extends AccountProvider {
  _Accounts(this.currentBalance);

  final double currentBalance;
  AccountModel? updated;
  double? addedOpeningBalance;

  @override
  double balanceOf(String accountId) => currentBalance;

  @override
  Future<void> updateAccount(AccountModel account) async {
    updated = account;
  }

  @override
  Future<AccountModel> addAccount({
    required String name,
    required String type,
    required double openingBalance,
    required String color,
    double? creditLimit,
    bool includeInTotal = true,
  }) async {
    addedOpeningBalance = openingBalance;
    return AccountModel(
      id: 'new-account',
      name: name,
      type: type,
      openingBalance: openingBalance,
      color: color,
      creditLimit: creditLimit,
      includeInTotal: includeInTotal,
      sortOrder: 0,
      createdAt: DateTime(2026),
    );
  }
}

AccountModel _account({String type = 'cash', double openingBalance = 0}) {
  return AccountModel(
    id: 'account-1',
    name: 'Daily account',
    type: type,
    openingBalance: openingBalance,
    color: '#C87941',
    sortOrder: 0,
    createdAt: DateTime(2026),
  );
}

Future<_Accounts> _pumpForm(
  WidgetTester tester, {
  AccountModel? account,
  double currentBalance = 0,
  String currency = 'IDR',
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final accounts = _Accounts(currentBalance);
  final settings = SettingsProvider();
  await settings.setCurrency(currency);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AccountProvider>.value(value: accounts),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ],
      child: MaterialApp(
        key: UniqueKey(),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: AccountForm(accountToEdit: account)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return accounts;
}

TextEditingController _balanceController(WidgetTester tester) {
  return tester
      .widget<KeypadAmountField>(find.byType(KeypadAmountField).first)
      .controller;
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
  await tester.pumpAndSettle();
}

Future<void> _openAmountField(WidgetTester tester, {int index = 0}) async {
  await tester.tap(find.byType(KeypadAmountField).at(index));
  await tester.pumpAndSettle();
  expect(find.byType(AmountKeypad), findsOneWidget);
}

void main() {
  testWidgets('edit shows the Home balance and reconciles only the baseline', (
    tester,
  ) async {
    final accounts = await _pumpForm(
      tester,
      account: _account(),
      currentBalance: 100,
    );

    expect(find.text('Current Balance'), findsOneWidget);
    expect(_balanceController(tester).text, '100');

    _balanceController(tester).text = '150';
    await _save(tester);

    expect(accounts.updated, isNotNull);
    expect(accounts.updated!.openingBalance, 50);
    expect(
      accounts.updated!.openingBalance + 100,
      150,
      reason: 'the existing transaction contribution remains untouched',
    );
  });

  testWidgets('an unchanged formatted balance preserves the exact baseline', (
    tester,
  ) async {
    final accounts = await _pumpForm(
      tester,
      account: _account(openingBalance: 0.4),
      currentBalance: 100.4,
    );

    expect(_balanceController(tester).text, '100');
    await _save(tester);

    expect(accounts.updated!.openingBalance, 0.4);
  });

  testWidgets('clearing current balance displays and saves an explicit zero', (
    tester,
  ) async {
    final accounts = await _pumpForm(
      tester,
      account: _account(),
      currentBalance: 100,
    );

    await _openAmountField(tester);
    await tester.tap(find.text('C'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(_balanceController(tester).text, '0');
    await _save(tester);
    expect(accounts.updated!.openingBalance, -100);
    expect(
      accounts.updated!.openingBalance + 100,
      0,
      reason:
          'transaction history is retained while the live balance becomes zero',
    );
  });

  testWidgets('backspacing the final digit displays zero after system back', (
    tester,
  ) async {
    await _pumpForm(tester, account: _account(), currentBalance: 1);

    await _openAmountField(tester);
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AmountKeypad), findsNothing);
    expect(_balanceController(tester).text, '0');
  });

  testWidgets('credit-card debt uses the positive owed amount from Home', (
    tester,
  ) async {
    final accounts = await _pumpForm(
      tester,
      account: _account(type: 'credit_card'),
      currentBalance: -100,
    );

    expect(find.text('Amount Owed'), findsOneWidget);
    expect(_balanceController(tester).text, '100');

    _balanceController(tester).text = '150';
    await _save(tester);

    expect(accounts.updated!.openingBalance, -50);
    expect(accounts.updated!.openingBalance - 100, -150);
  });

  testWidgets('clearing credit-card debt displays and saves zero', (
    tester,
  ) async {
    final accounts = await _pumpForm(
      tester,
      account: _account(type: 'credit_card'),
      currentBalance: -100,
    );

    await _openAmountField(tester);
    await tester.tap(find.text('C'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(_balanceController(tester).text, '0');
    await _save(tester);
    expect(accounts.updated!.openingBalance, 100);
    expect(accounts.updated!.openingBalance - 100, 0);
  });

  testWidgets('an optional credit limit remains blank after clearing', (
    tester,
  ) async {
    await _pumpForm(tester, account: _account(type: 'credit_card'));
    final creditLimit = tester
        .widget<KeypadAmountField>(find.byType(KeypadAmountField).at(1))
        .controller;
    expect(creditLimit.text, isEmpty);

    await _openAmountField(tester, index: 1);
    await tester.tap(find.text('C'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(creditLimit.text, isEmpty);
  });

  testWidgets('an overdrawn non-credit balance remains signed and editable', (
    tester,
  ) async {
    final accounts = await _pumpForm(
      tester,
      account: _account(),
      currentBalance: -100,
    );

    expect(find.text('Current Balance'), findsOneWidget);
    expect(_balanceController(tester).text, '-100');

    await _openAmountField(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(AmountKeypad), findsNothing);
    expect(_balanceController(tester).text, '-100');

    _balanceController(tester).text = '-150';
    await _save(tester);
    expect(accounts.updated!.openingBalance, -50);
  });

  testWidgets('decimal currencies reconcile to the entered cents', (
    tester,
  ) async {
    final accounts = await _pumpForm(
      tester,
      account: _account(),
      currentBalance: 100.25,
      currency: 'USD',
    );

    expect(_balanceController(tester).text, '100.25');
    _balanceController(tester).text = '150.75';
    await _save(tester);

    expect(accounts.updated!.openingBalance, closeTo(50.5, 0.000001));
  });

  testWidgets('zero and the maximum supported balance are accepted', (
    tester,
  ) async {
    final zeroAccounts = await _pumpForm(tester, account: _account());
    expect(_balanceController(tester).text, '0');
    await _save(tester);
    expect(zeroAccounts.updated!.openingBalance, 0);

    final maxAccounts = await _pumpForm(tester, account: _account());
    _balanceController(tester).text = '999,999,999,999';
    await _save(tester);
    expect(maxAccounts.updated!.openingBalance, AppConstants.maxAmount);
  });

  testWidgets('a balance above the supported maximum is rejected', (
    tester,
  ) async {
    final accounts = await _pumpForm(tester, account: _account());
    _balanceController(tester).text = '1,000,000,000,000';
    await _save(tester);

    expect(accounts.updated, isNull);
    expect(find.text('Please enter a valid amount'), findsOneWidget);
  });

  testWidgets('new accounts store the entered current balance as opening', (
    tester,
  ) async {
    final accounts = await _pumpForm(tester);
    expect(find.text('Current Balance'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'New account');
    _balanceController(tester).text = '250';
    await _save(tester);

    expect(accounts.addedOpeningBalance, 250);
  });

  testWidgets('the current balance label is localized in Indonesian', (
    tester,
  ) async {
    await _pumpForm(tester, account: _account(), locale: const Locale('id'));

    expect(find.text('Saldo Saat Ini'), findsOneWidget);
  });
}
