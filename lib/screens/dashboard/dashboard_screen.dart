import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/account_provider.dart';
import '../../core/constants/app_constants.dart';
import 'widgets/balance_card.dart';
import 'widgets/net_worth_card.dart';
import 'widgets/summary_row.dart';
import 'widgets/burn_rate_indicator.dart';
import 'widgets/forecast_card.dart';
import 'widgets/budget_overview.dart';
import 'widgets/upcoming_bills.dart';
import 'widgets/goals_debts_teaser.dart';
import 'widgets/recent_transactions.dart';
import 'widgets/period_selector.dart';
import '../../widgets/error_state.dart';
import '../../l10n/app_localizations.dart';

/// Dashboard — the home screen showing balance, summary, budgets, and recent activity.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The app's own name doesn't need to occupy the app bar — this
        // slot is more useful showing which period is loaded and letting
        // the user step back to a previous one (see PeriodSelector).
        title: const PeriodSelector(),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final settings = context.read<SettingsProvider>();
          await context
              .read<TransactionProvider>()
              .loadTransactions(payday: settings.payday);
          await context
              .read<BudgetProvider>()
              .loadBudgets(payday: settings.payday);
          await context.read<AccountProvider>().loadAccounts();
        },
        child: Consumer2<TransactionProvider, BudgetProvider>(
          builder: (context, txProvider, budgetProvider, child) {
            if (txProvider.error != null || budgetProvider.error != null) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  ErrorState(
                    title: AppLocalizations.of(context)!.errorFailedToLoadData,
                    message: txProvider.error ?? budgetProvider.error,
                    onRetry: () {
                      final settings = context.read<SettingsProvider>();
                      txProvider.loadTransactions(payday: settings.payday);
                      budgetProvider.loadBudgets(payday: settings.payday);
                    },
                  ),
                ],
              );
            }

            // Budgets and upcoming bills are inherently "right now"
            // concepts — showing them while the user has navigated to a
            // past period would misleadingly imply they apply to it.
            final showCurrentPeriodSections = txProvider.isViewingCurrentPeriod;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                AppConstants.spacingSm,
                AppConstants.spacingLg,
                AppConstants.fabClearance,
              ),
              children: [
                const NetWorthCard(),
                const SizedBox(height: AppConstants.spacingXxxl),
                const BalanceCard(),
                const SizedBox(height: AppConstants.spacingLg),
                const SummaryRow(),
                if (showCurrentPeriodSections) ...[
                  const SizedBox(height: AppConstants.spacingLg),
                  const BurnRateIndicator(),
                  const SizedBox(height: AppConstants.spacingXxxl),
                  const ForecastCard(),
                  const SizedBox(height: AppConstants.spacingXxxl),
                  const BudgetOverview(),
                  const SizedBox(height: AppConstants.spacingXxxl),
                  const UpcomingBills(),
                  const SizedBox(height: AppConstants.spacingXxxl),
                  const GoalsDebtsTeaser(),
                ],
                const SizedBox(height: AppConstants.spacingXxxl),
                const RecentTransactions(),
              ],
            );
          },
        ),
      ),
    );
  }
}
