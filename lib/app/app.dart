import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/budget_provider.dart';
import '../core/services/recurring_service.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/transactions/transaction_history_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/transactions/widgets/quick_add_sheet.dart';
import '../core/constants/app_colors.dart';
import '../l10n/app_localizations.dart';

/// Root app widget — handles initialization, onboarding routing,
/// and the main bottom navigation shell.
class FintaApp extends StatefulWidget {
  const FintaApp({super.key});

  @override
  State<FintaApp> createState() => _FintaAppState();
}

class _FintaAppState extends State<FintaApp> {
  bool _isInitialized = false;
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    TransactionHistoryScreen(),
    AnalyticsScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final settings = context.read<SettingsProvider>();
    final categories = context.read<CategoryProvider>();
    final recurring = context.read<RecurringProvider>();
    final transactions = context.read<TransactionProvider>();
    final budgets = context.read<BudgetProvider>();

    await settings.init();
    if (!mounted) return;

    await categories.loadCategories();
    if (!mounted) return;

    await recurring.loadRecurringTransactions();
    if (!mounted) return;

    // Process any due recurring transactions
    final recurringService = context.read<RecurringService>();
    await recurringService.processRecurringTransactions();
    if (!mounted) return;

    await transactions.loadTransactions(payday: settings.payday);
    if (!mounted) return;

    await budgets.loadBudgets(payday: settings.payday);

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _openAddTransaction() {
    QuickAddSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final settings = context.watch<SettingsProvider>();
    if (!settings.hasCompletedOnboarding) {
      return const OnboardingScreen();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _openAddTransaction,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: AppLocalizations.of(context)!.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.receipt_long_outlined),
              activeIcon: const Icon(Icons.receipt_long),
              label: AppLocalizations.of(context)!.transactions,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.pie_chart_outline),
              activeIcon: const Icon(Icons.pie_chart),
              label: AppLocalizations.of(context)!.analytics,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.more_horiz_outlined),
              activeIcon: const Icon(Icons.more_horiz),
              label: AppLocalizations.of(context)!.more,
            ),
          ],
        ),
      ),
    );
  }
}
