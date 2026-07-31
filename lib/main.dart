import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/analytics_provider.dart';
import 'providers/account_provider.dart';
import 'repositories/transaction_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/recurring_repository.dart';
import 'repositories/budget_repository.dart';
import 'repositories/account_repository.dart';
import 'core/services/recurring_service.dart';
import 'l10n/app_localizations.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FintaRoot());
}

class FintaRoot extends StatelessWidget {
  const FintaRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final transactionRepo = TransactionRepository();
    final categoryRepo = CategoryRepository();
    final recurringRepo = RecurringRepository();
    final budgetRepo = BudgetRepository();
    final accountRepo = AccountRepository();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider(repository: categoryRepo)),
        ChangeNotifierProvider(create: (_) => TransactionProvider(repository: transactionRepo)),
        ChangeNotifierProvider(create: (_) => RecurringProvider(repository: recurringRepo)),
        ChangeNotifierProvider(
          create: (_) => BudgetProvider(
            repository: budgetRepo,
            transactionRepo: transactionRepo,
          ),
        ),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider(repository: transactionRepo)),
        ChangeNotifierProvider(create: (_) => AccountProvider(repository: accountRepo)),
        Provider<RecurringService>(
          create: (_) => RecurringService(recurringRepo: recurringRepo),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Finta',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: settings.locale,
            home: const FintaApp(),
          );
        },
      ),
    );
  }
}
