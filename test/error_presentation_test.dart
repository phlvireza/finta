import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finta/core/theme/app_theme.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/providers/analytics_provider.dart';
import 'package:finta/providers/account_provider.dart';
import 'package:finta/providers/budget_provider.dart';
import 'package:finta/providers/category_provider.dart';
import 'package:finta/providers/settings_provider.dart';
import 'package:finta/providers/transaction_provider.dart';
import 'package:finta/screens/analytics/analytics_screen.dart';
import 'package:finta/screens/dashboard/dashboard_screen.dart';
import 'package:finta/screens/transactions/transaction_history_screen.dart';
import 'package:finta/widgets/error_state.dart';

const _diagnostic = 'DatabaseException: private note, SQL query, file path';

class _Transactions extends TransactionProvider {
  int loads = 0;
  @override
  String? get error => _diagnostic;
  @override
  Future<void> loadTransactions({required int payday, int? offset}) async {
    loads++;
  }

  @override
  Future<void> loadAllTransactions() async {
    loads++;
  }
}

class _Analytics extends AnalyticsProvider {
  int loads = 0;
  @override
  String? get error => _diagnostic;
  @override
  Future<void> loadForCurrentPeriod(int payday) async {
    loads++;
  }
}

class _Budgets extends BudgetProvider {
  @override
  Future<void> loadBudgets({required int payday}) async {}
}

void main() {
  for (final language in ['en', 'id']) {
    for (final screen in ['dashboard', 'history', 'analytics']) {
      testWidgets('$screen hides diagnostics and retries in $language', (
        tester,
      ) async {
        final transactions = _Transactions();
        final analytics = _Analytics();
        addTearDown(transactions.dispose);
        addTearDown(analytics.dispose);
        final home = switch (screen) {
          'dashboard' => const DashboardScreen(),
          'history' => const TransactionHistoryScreen(),
          _ => const AnalyticsScreen(),
        };
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => SettingsProvider()),
              ChangeNotifierProvider(create: (_) => CategoryProvider()),
              ChangeNotifierProvider(create: (_) => AccountProvider()),
              ChangeNotifierProvider<TransactionProvider>.value(
                value: transactions,
              ),
              ChangeNotifierProvider<AnalyticsProvider>.value(value: analytics),
              ChangeNotifierProvider<BudgetProvider>(create: (_) => _Budgets()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ErrorState), findsOneWidget);
        final context = tester.element(find.byType(ErrorState));
        final loc = AppLocalizations.of(context)!;
        expect(find.text(loc.errorFailedToLoadData), findsOneWidget);
        expect(find.textContaining('DatabaseException'), findsNothing);
        expect(find.textContaining('private note'), findsNothing);
        final before = screen == 'analytics'
            ? analytics.loads
            : transactions.loads;
        await tester.tap(find.text(loc.retry));
        await tester.pumpAndSettle();
        expect(
          screen == 'analytics' ? analytics.loads : transactions.loads,
          before + 1,
        );
        expect(transactions.error, _diagnostic);
        expect(analytics.error, _diagnostic);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
