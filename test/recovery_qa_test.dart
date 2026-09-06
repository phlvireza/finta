import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:finta/app/app.dart';
import 'package:finta/core/theme/app_theme.dart';
import 'package:finta/core/services/recurring_service.dart';
import 'package:finta/core/services/budget_expiry_service.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/models/transaction_model.dart';
import 'package:finta/providers/account_provider.dart';
import 'package:finta/providers/analytics_provider.dart';
import 'package:finta/providers/budget_provider.dart';
import 'package:finta/providers/category_provider.dart';
import 'package:finta/providers/debt_provider.dart';
import 'package:finta/providers/goal_provider.dart';
import 'package:finta/providers/insights_provider.dart';
import 'package:finta/providers/recurring_provider.dart';
import 'package:finta/providers/settings_provider.dart';
import 'package:finta/providers/template_provider.dart';
import 'package:finta/providers/transaction_provider.dart';
import 'package:finta/repositories/transaction_repository.dart';
import 'package:finta/screens/onboarding/onboarding_screen.dart';
import 'package:finta/screens/transactions/add_transaction_screen.dart';
import 'package:finta/screens/transactions/widgets/quick_add_sheet.dart';
import 'package:finta/screens/transactions/widgets/account_picker.dart';
import 'package:finta/screens/transactions/widgets/category_picker.dart';
import 'package:finta/widgets/amount_input_field.dart';
import 'package:finta/widgets/error_state.dart';
import 'package:finta/widgets/transaction_save_recovery.dart';
import 'package:finta/models/goal_model.dart';
import 'package:finta/models/debt_model.dart';
import 'package:finta/screens/goals/widgets/contribute_to_goal_sheet.dart';
import 'package:finta/screens/debts/widgets/repayment_sheet.dart';
import 'package:finta/widgets/keypad_amount_field.dart';

class _Settings extends SettingsProvider {
  int attempts = 0;
  Completer<void>? pending;
  @override
  Future<void> init() async {
    attempts++;
    await pending?.future;
  }
}

class _Accounts extends AccountProvider {
  @override
  Future<void> loadAccounts() async {}
}

class _Categories extends CategoryProvider {
  @override
  Future<void> loadCategories() async {}
  @override
  Future<void> localizeDefaultNames(String languageCode) async {}
}

class _Budgets extends BudgetProvider {
  @override
  Future<void> loadBudgets({required int payday}) async {}
}

class _Goals extends GoalProvider {
  @override
  Future<void> loadGoals() async {}
}

class _Debts extends DebtProvider {
  @override
  Future<void> loadDebts() async {}
}

class _Templates extends TemplateProvider {
  @override
  Future<void> loadTemplates() async {}
}

class _Recurring extends RecurringProvider {
  @override
  Future<void> loadRecurringTransactions() async {}
}

class _CatchUp extends RecurringService {
  int runs = 0;
  @override
  Future<int> processRecurringTransactions() async {
    runs++;
    return 0;
  }
}

class _Expiry extends BudgetExpiryService {
  @override
  Future<int> expireFinishedBudgets({
    required int payday,
    DateTime? today,
  }) async => 0;
}

class _Analytics extends AnalyticsProvider {
  @override
  Future<void> loadForCurrentPeriod(int payday) async {}
}

class _Insights extends InsightsProvider {
  @override
  Future<({bool isAnomaly, double mean})?> checkAnomaly(
    String categoryId,
    double amount,
  ) async => null;
}

// Exercise the real TransactionProvider writes against disposable SQLite,
// while injecting failures only into the subsequent refresh query.
class _Ledger extends TransactionRepository {
  final Database db;
  int refreshFailures = 0;
  int refreshes = 0;
  _Ledger(this.db);
  @override
  Future<void> insert(TransactionModel tx) async {
    await db.insert('transactions', tx.toMap());
  }

  @override
  Future<bool> hasAnyNonTransferTransaction() async => true;
  @override
  Future<List<TransactionModel>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    refreshes++;
    if (refreshFailures-- > 0) throw StateError('private database failure');
    return (await db.query(
      'transactions',
    )).map(TransactionModel.fromMap).toList();
  }

  @override
  Future<double> getSumByTypeAndDateRange(
    String type,
    DateTime start,
    DateTime end,
  ) async => 0;
}

Widget _app(
  Widget home,
  _Settings settings,
  TransactionProvider transactions, {
  bool dark = false,
  _CatchUp? catchUp,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
    ChangeNotifierProvider<AccountProvider>(create: (_) => _Accounts()),
    ChangeNotifierProvider<CategoryProvider>(create: (_) => _Categories()),
    ChangeNotifierProvider<BudgetProvider>(create: (_) => _Budgets()),
    ChangeNotifierProvider<GoalProvider>(create: (_) => _Goals()),
    ChangeNotifierProvider<DebtProvider>(create: (_) => _Debts()),
    ChangeNotifierProvider<TemplateProvider>(create: (_) => _Templates()),
    ChangeNotifierProvider<RecurringProvider>(create: (_) => _Recurring()),
    ChangeNotifierProvider<AnalyticsProvider>(create: (_) => _Analytics()),
    ChangeNotifierProvider<InsightsProvider>(create: (_) => _Insights()),
    Provider<RecurringService>(create: (_) => catchUp ?? _CatchUp()),
    Provider<BudgetExpiryService>(create: (_) => _Expiry()),
  ],
  child: MaterialApp(
    theme: dark ? AppTheme.dark : AppTheme.light,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting();
  });
  late Database db;
  late _Ledger ledger;
  late TransactionProvider transactions;
  late _Settings settings;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE transactions (id TEXT PRIMARY KEY, type TEXT, amount REAL, categoryId TEXT, accountId TEXT, transferId TEXT, isTransfer INTEGER, merchant TEXT, date TEXT, note TEXT, recurringId TEXT, goalId TEXT, debtId TEXT, createdAt TEXT, updatedAt TEXT)',
    );
    ledger = _Ledger(db);
    transactions = TransactionProvider(repository: ledger);
    settings = _Settings();
  });
  tearDown(() async {
    transactions.dispose();
    settings.dispose();
    await db.close();
  });

  for (final dark in [false, true]) {
    for (final kind in ['goal', 'borrowed', 'lent']) {
      for (final rapid in [false, true]) {
        testWidgets(
          'tagged save $kind dark=$dark rapid=$rapid never reposts after refresh failure',
          (tester) async {
            tester.view.physicalSize = const Size(412, 915);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final sheet = kind == 'goal'
                ? ContributeToGoalSheet(
                    goal: GoalModel(
                      id: 'goal',
                      name: 'Savings',
                      targetAmount: 1000,
                      color: '#C87941',
                      createdAt: DateTime(2026),
                    ),
                  )
                : RepaymentSheet(
                    debt: DebtModel(
                      id: 'debt',
                      name: 'Loan',
                      type: kind,
                      principal: 1000,
                      createdAt: DateTime(2026),
                    ),
                  );
            await tester.pumpWidget(
              _app(
                Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => sheet,
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
                settings,
                transactions,
                dark: dark,
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            tester
                    .widget<KeypadAmountField>(find.byType(KeypadAmountField))
                    .controller
                    .text =
                '100';
            tester
                .widget<AccountPicker>(find.byType(AccountPicker))
                .onAccountSelected('cash');
            await tester.pump();
            ledger.refreshFailures = 2;
            final save = tester
                .widget<ElevatedButton>(find.byType(ElevatedButton).last)
                .onPressed!;
            await tester.runAsync(() async {
              final pending = (save as Future<void> Function())();
              if (rapid) save();
              await pending;
            });
            await tester.pumpAndSettle();
            final rows = (await tester.runAsync(
              () => db.query('transactions'),
            ))!;
            expect(rows, hasLength(1));
            expect(rows.single['amount'], 100);
            expect(rows.single['type'], kind == 'lent' ? 'income' : 'expense');
            expect(rows.single['goalId'], kind == 'goal' ? 'goal' : isNull);
            expect(rows.single['debtId'], kind == 'goal' ? isNull : 'debt');
            expect(find.byType(TransactionSaveRecovery), findsOneWidget);
            expect(find.byType(KeypadAmountField), findsNothing);
            expect(find.textContaining('private database'), findsNothing);
            for (var retry = 0; retry < 2; retry++) {
              final action = tester
                  .widget<ErrorState>(find.byType(ErrorState))
                  .onRetry!;
              await tester.runAsync(() async {
                final pending = (action as Future<void> Function())();
                action();
                await pending;
              });
              await tester.pumpAndSettle();
              expect(
                await tester.runAsync(() => db.query('transactions')),
                hasLength(1),
              );
            }
            expect(find.byType(TransactionSaveRecovery), findsNothing);
            expect(find.text('Open'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
    testWidgets(
      'startup failure retries once and reaches onboarding dark=$dark',
      (tester) async {
        settings.pending = Completer<void>();
        final catchUp = _CatchUp();
        await tester.pumpWidget(
          _app(
            const FintaApp(),
            settings,
            transactions,
            dark: dark,
            catchUp: catchUp,
          ),
        );
        settings.pending!.completeError(StateError('private database failure'));
        await tester.pumpAndSettle();
        expect(find.byType(ErrorState), findsOneWidget);
        expect(find.textContaining('private database'), findsNothing);
        settings.pending = Completer<void>();
        final retry = tester
            .widget<ErrorState>(find.byType(ErrorState))
            .onRetry!;
        await tester.runAsync(() async {
          final retryFuture = (retry as Future<void> Function())();
          retry();
          expect(settings.attempts, 2);
          settings.pending!.complete();
          await retryFuture;
        });
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(catchUp.runs, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    for (final quick in [false, true]) {
      testWidgets(
        'committed save survives repeated refresh failures quick=$quick dark=$dark',
        (tester) async {
          ledger.refreshFailures = 2;
          tester.view.physicalSize = const Size(412, 915);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _app(
              Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => quick
                            ? const Scaffold(
                                body: QuickAddSheet(
                                  initialCategoryId: 'food',
                                  initialAmount: 100,
                                ),
                              )
                            : const AddTransactionScreen(),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
              settings,
              transactions,
              dark: dark,
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          tester
              .widget<AccountPicker>(find.byType(AccountPicker).first)
              .onAccountSelected('cash');
          if (!quick) {
            tester
                    .widget<AmountInputField>(find.byType(AmountInputField))
                    .controller
                    .text =
                '100';
            tester
                .widget<CategoryPicker>(find.byType(CategoryPicker))
                .onCategorySelected('food');
          }
          await tester.pump();
          final save = tester
              .widget<ElevatedButton>(find.byType(ElevatedButton).last)
              .onPressed!;
          await tester.runAsync(() async {
            await (save as Future<void> Function())();
          });
          await tester.pumpAndSettle();
          expect(find.byType(TransactionSaveRecovery), findsOneWidget);
          expect(
            await tester.runAsync(() => db.query('transactions')),
            hasLength(1),
          );
          // Even an old callback cannot repost after the commit.
          save();
          for (var attempt = 0; attempt < 2; attempt++) {
            final retry = tester
                .widget<ErrorState>(find.byType(ErrorState))
                .onRetry!;
            await tester.runAsync(() async {
              final pending = (retry as Future<void> Function())();
              retry();
              await pending;
            });
            await tester.pumpAndSettle();
            expect(
              await tester.runAsync(() => db.query('transactions')),
              hasLength(1),
            );
          }
          expect(ledger.refreshes, 3);
          expect(find.text('Open'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
