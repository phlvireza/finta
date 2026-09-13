import 'package:finta/core/utils/merchant_utils.dart';
import 'package:finta/screens/analytics/widgets/top_merchants_list.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/models/budget_model.dart';
import 'package:finta/models/transaction_model.dart';
import 'package:finta/providers/account_provider.dart';
import 'package:finta/providers/analytics_provider.dart';
import 'package:finta/providers/budget_provider.dart';
import 'package:finta/providers/category_provider.dart';
import 'package:finta/providers/debt_provider.dart';
import 'package:finta/providers/goal_provider.dart';
import 'package:finta/providers/settings_provider.dart';
import 'package:finta/providers/transaction_provider.dart';
import 'package:finta/repositories/budget_repository.dart';
import 'package:finta/repositories/transaction_repository.dart';
import 'package:finta/screens/budgets/budget_detail_screen.dart';
import 'package:finta/screens/transactions/widgets/transaction_tile.dart';
import 'package:finta/screens/transactions/add_transaction_screen.dart';

final _today = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
);
TransactionModel _transaction(String id) => TransactionModel(
  id: id,
  type: 'expense',
  amount: 25,
  categoryId: 'food',
  accountId: 'cash',
  date: _today,
  createdAt: _today,
  updatedAt: _today,
  note: id,
  merchant: 'Cafe',
  goalId: 'goal',
  debtId: 'debt',
  recurringId: 'schedule',
);

class _Ledger extends TransactionRepository {
  final rows = [_transaction('Lunch')];
  int deletes = 0;
  @override
  Future<List<TransactionModel>> getAll() async => List.of(rows);
  @override
  Future<TransactionModel?> getById(String id) async =>
      rows.where((t) => t.id == id).firstOrNull;
  @override
  Future<void> delete(String id) async {
    deletes++;
    rows.removeWhere((t) => t.id == id);
  }

  @override
  Future<bool> hasAnyNonTransferTransaction() async =>
      rows.any((t) => !t.isTransfer);
  @override
  Future<List<TransactionModel>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => rows
      .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end))
      .toList();
  @override
  Future<double> getSumByTypeAndDateRange(
    String type,
    DateTime start,
    DateTime end,
  ) async => (await getByDateRange(
    start,
    end,
  )).where((t) => t.type == type).fold<double>(0, (sum, t) => sum + t.amount);
  @override
  Future<List<TransactionModel>> getByTypeAndDateRange(
    String type,
    DateTime start,
    DateTime end,
  ) async =>
      (await getByDateRange(start, end)).where((t) => t.type == type).toList();
  @override
  Future<List<TransactionModel>> getCategoriesByDateRange(
    List<String> ids,
    DateTime start,
    DateTime end,
  ) async => (await getByDateRange(
    start,
    end,
  )).where((t) => ids.contains(t.categoryId)).toList();
  @override
  Future<double> getCategoriesSumByDateRange(
    List<String> ids,
    DateTime start,
    DateTime end,
  ) async => (await getCategoriesByDateRange(
    ids,
    start,
    end,
  )).fold<double>(0, (sum, t) => sum + t.amount);
}

class _BudgetRepo extends BudgetRepository {
  @override
  Future<List<BudgetModel>> getAll() async => [
    for (final scope in ['overall', 'group', 'category'])
      BudgetModel(
        id: scope,
        name: scope,
        scope: scope,
        amount: 100,
        categoryIds: scope == 'overall' ? [] : ['food'],
        isActive: true,
        createdAt: _today,
        updatedAt: _today,
      ),
  ];
}

class _Budgets extends BudgetProvider {
  final List<Completer<List<TransactionModel>>> pending = [];
  bool defer = false;
  _Budgets(_Ledger ledger)
    : super(repository: _BudgetRepo(), transactionRepo: ledger);
  @override
  Future<List<TransactionModel>> transactionsFor(
    BudgetModel budget, {
    required ({DateTime start, DateTime end}) period,
  }) {
    if (!defer) return super.transactionsFor(budget, period: period);
    final result = Completer<List<TransactionModel>>();
    pending.add(result);
    return result.future;
  }
}

class _Accounts extends AccountProvider {
  int refreshes = 0;
  @override
  Future<void> loadAccounts() async {
    refreshes++;
  }
}

class _Analytics extends AnalyticsProvider {
  int refreshes = 0;
  @override
  Future<void> loadForCurrentPeriod(int payday) async {
    refreshes++;
  }
}

class _Goals extends GoalProvider {
  int refreshes = 0;
  @override
  Future<void> loadGoals() async {
    refreshes++;
  }
}

class _Debts extends DebtProvider {
  int refreshes = 0;
  @override
  Future<void> loadDebts() async {
    refreshes++;
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    _Ledger ledger,
    _Budgets budgets,
    _Accounts accounts,
    _Analytics analytics,
    _Goals goals,
    _Debts debts, {
    Widget? home,
  }) async {
    final transactions = TransactionProvider(repository: ledger);
    await transactions.loadAllTransactions();
    await transactions.loadTransactions(payday: 1);
    addTearDown(transactions.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TransactionProvider>.value(
            value: transactions,
          ),
          ChangeNotifierProvider<BudgetProvider>.value(value: budgets),
          ChangeNotifierProvider<AccountProvider>.value(value: accounts),
          ChangeNotifierProvider<AnalyticsProvider>.value(value: analytics),
          ChangeNotifierProvider<GoalProvider>.value(value: goals),
          ChangeNotifierProvider<DebtProvider>.value(value: debts),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home ?? const BudgetDetailScreen(budgetId: 'overall'),
        ),
      ),
    );
    if (budgets.defer) {
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
  }

  for (final swipe in [true, false]) {
    testWidgets(
      'delete via ${swipe ? 'swipe' : 'transaction detail'} updates all budget scopes and linked providers',
      (tester) async {
        final ledger = _Ledger();
        final budgets = _Budgets(ledger);
        final accounts = _Accounts();
        final analytics = _Analytics();
        final goals = _Goals();
        final debts = _Debts();
        await budgets.loadBudgets(payday: 1);
        await mount(tester, ledger, budgets, accounts, analytics, goals, debts);
        expect(
          budgets.budgetStatuses.values.every((s) => s.spent == 25),
          isTrue,
        );
        await tester.ensureVisible(find.byType(TransactionTile));
        if (swipe) {
          await tester.drag(
            find.byType(TransactionTile),
            const Offset(-500, 0),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
        } else {
          await tester.tap(find.byType(TransactionTile));
          await tester.pumpAndSettle();
          expect(find.byType(AddTransactionScreen), findsOneWidget);
          await tester.tap(find.text('Delete'));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(ledger.deletes, 1);
        expect(ledger.rows, isEmpty);
        expect(
          budgets.budgetStatuses.values.every(
            (s) => s.spent == 0 && s.remaining == 100,
          ),
          isTrue,
        );
        expect(find.byType(TransactionTile), findsNothing);
        expect(find.byType(AddTransactionScreen), findsNothing);
        expect(accounts.refreshes, 1);
        expect(analytics.refreshes, 1);
        expect(goals.refreshes, 1);
        expect(debts.refreshes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('deleting from merchant details updates its count and total', (
    tester,
  ) async {
    final ledger = _Ledger();
    final budgets = _Budgets(ledger);
    await budgets.loadBudgets(payday: 1);
    await mount(
      tester,
      ledger,
      budgets,
      _Accounts(),
      _Analytics(),
      _Goals(),
      _Debts(),
      home: Scaffold(
        body: MerchantTransactionsSheet(
          merchant: const MerchantAnalytics(
            merchant: 'Cafe',
            key: 'cafe',
            total: 25,
            count: 1,
          ),
          start: _today,
          end: _today,
          isIncome: false,
        ),
      ),
    );
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.byType(TransactionTile), findsOneWidget);
    await tester.tap(find.byType(TransactionTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionTile), findsNothing);
    expect(find.text('Rp 0'), findsOneWidget);
    expect(ledger.deletes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an older budget detail request cannot restore deleted rows', (
    tester,
  ) async {
    final ledger = _Ledger();
    final budgets = _Budgets(ledger)..defer = true;
    await budgets.loadBudgets(payday: 1);
    await mount(
      tester,
      ledger,
      budgets,
      _Accounts(),
      _Analytics(),
      _Goals(),
      _Debts(),
    );
    expect(budgets.pending, hasLength(1));
    final oldRows = List<TransactionModel>.of(ledger.rows);
    ledger.rows.clear();
    await budgets.loadBudgets(payday: 1);
    await tester.pump();
    expect(budgets.pending, hasLength(2));
    budgets.pending.last.complete([]);
    await tester.pumpAndSettle();
    budgets.pending.first.complete(oldRows);
    await tester.pumpAndSettle();
    expect(find.byType(TransactionTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
