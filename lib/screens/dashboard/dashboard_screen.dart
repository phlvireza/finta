import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/account_provider.dart';
import '../../core/constants/app_constants.dart';
import 'widgets/balance_card.dart';
import 'widgets/burn_rate_indicator.dart';
import 'widgets/spending_heatmap.dart';
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
        actions: const [
          _LanguageToggleButton(),
          _ThemeToggleButton(),
          _HideBalancesButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final settings = context.read<SettingsProvider>();
          await context
              .read<TransactionProvider>()
              .loadTransactions(payday: settings.payday);
          if (!context.mounted) return;
          await context
              .read<BudgetProvider>()
              .loadBudgets(payday: settings.payday);
          if (!context.mounted) return;
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
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.fabClearance,
              ),
              children: [
                const BalanceCard(),
                if (showCurrentPeriodSections) ...[
                  const SizedBox(height: AppConstants.spacingLg),
                  const BurnRateIndicator(),
                  const SizedBox(height: AppConstants.spacingLg),
                  const UpcomingBills(),
                  const SizedBox(height: AppConstants.spacingLg),
                  const GoalsDebtsTeaser(),
                ],
                const SizedBox(height: AppConstants.spacingLg),
                const RecentTransactions(),
                // Last, and outside the gate above: it answers "how did this
                // period go overall", which is a summary of everything above
                // rather than something to act on — and a past period's
                // pattern is as meaningful as the current one's, so the grid
                // draws whichever period the selector is on.
                const SizedBox(height: AppConstants.spacingLg),
                const SpendingHeatmap(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The hide-balances toggle. It lives in the app bar rather than on a card
/// because it is a screen-level privacy switch — it masks the period net,
/// the income/expense stats and every account balance at once, so hanging
/// it off any one of them would understate its reach.
class _HideBalancesButton extends StatelessWidget {
  const _HideBalancesButton();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context)!;

    return IconButton(
      icon: Icon(
        settings.hideBalances ? Icons.visibility_off : Icons.visibility,
        size: 20,
      ),
      tooltip: settings.hideBalances ? loc.showBalances : loc.hideBalances,
      onPressed: () => settings.setHideBalances(!settings.hideBalances),
    );
  }
}

/// One-tap light/dark flip, sitting beside the hide-balances eye because both
/// are instant appearance switches with no data consequences.
///
/// This deliberately only writes `light` or `dark`, never `system` — a
/// two-state button can't express three states without becoming a guessing
/// game. `system` stays reachable from Settings → Theme, which remains the
/// canonical control.
class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Read the *resolved* brightness rather than SettingsProvider.themeMode:
    // under ThemeMode.system the stored mode has no light/dark answer, so
    // flipping it would need to guess. MaterialApp has already resolved the
    // platform brightness by the time this builds, so this always matches
    // what the user is actually looking at — the first tap off `system`
    // therefore visibly changes something.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      // Icon shows the current state and the tooltip names the action, which
      // is the same split the eye button next to it uses.
      icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 20),
      tooltip: isDark ? loc.switchToLightTheme : loc.switchToDarkTheme,
      onPressed: () => context
          .read<SettingsProvider>()
          .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

/// One-tap language flip, next to the theme toggle for the same reason that
/// one moved out of Settings: switching language was four taps deep (More,
/// Settings, Language, then a sheet) for something a bilingual user flips
/// often, and it changes nothing but presentation.
///
/// Unlike the theme button, this one loses nothing by being two-state — the
/// app ships exactly two locales, so a toggle can express all of them.
/// Settings → Language stays as the canonical control and is untouched.
class _LanguageToggleButton extends StatelessWidget {
  const _LanguageToggleButton();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final isEnglish = settings.languageCode == 'en';

    return IconButton(
      // The current code rather than a globe glyph: a translate icon says
      // "language lives here" but not which one is on, and the two-letter
      // code reads at a glance in either locale. Same split as the buttons
      // beside it — the control shows the current state, the tooltip names
      // what tapping does.
      icon: Text(
        isEnglish ? 'EN' : 'ID',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        ),
      ),
      tooltip: isEnglish ? loc.switchToIndonesian : loc.switchToEnglish,
      onPressed: () => settings.setLanguage(isEnglish ? 'id' : 'en'),
    );
  }
}
