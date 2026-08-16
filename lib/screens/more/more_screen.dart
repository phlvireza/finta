import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/section_card.dart';
import '../../widgets/tinted_icon.dart';
import '../accounts/manage_accounts_screen.dart';
import '../analytics/analytics_screen.dart';
import '../categories/manage_categories_screen.dart';
import '../recurring/recurring_list_screen.dart';
import '../goals/goals_list_screen.dart';
import '../debts/debts_list_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../settings/settings_screen.dart';
import '../../l10n/app_localizations.dart';

/// Hub for the lower-frequency surfaces — accounts, analytics, categories,
/// recurring transactions, goals, debts, and settings (which itself hosts
/// currency, theme, payday, and data export). Keeping these off the main
/// tab bar means the four primary destinations (Home, Transactions,
/// Budgets, More) stay one tap away, and every surface here is reachable
/// from anywhere in the app instead of only from the dashboard.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.more)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          AppConstants.spacingMd,
          AppConstants.spacingLg,
          AppConstants.fabClearance,
        ),
        children: [
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MoreTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: loc.accounts,
                  color: theme.colorScheme.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ManageAccountsScreen()),
                  ),
                ),
                const Divider(),
                _MoreTile(
                  icon: Icons.pie_chart_outline,
                  label: loc.analytics,
                  color: theme.colorScheme.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                ),
                const Divider(),
                _MoreTile(
                  icon: Icons.category_outlined,
                  label: loc.categories,
                  color: theme.colorScheme.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
                  ),
                ),
                const Divider(),
                _MoreTile(
                  icon: Icons.repeat,
                  label: loc.recurring,
                  color: theme.colorScheme.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RecurringListScreen()),
                  ),
                ),
                const Divider(),
                _MoreTile(
                  icon: Icons.subscriptions_outlined,
                  label: loc.subscriptions,
                  color: theme.colorScheme.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
                  ),
                ),
                const Divider(),
                _MoreTile(
                  icon: Icons.savings_outlined,
                  label: loc.goals,
                  color: theme.colorScheme.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GoalsListScreen()),
                  ),
                ),
                const Divider(),
                _MoreTile(
                  icon: Icons.handshake_outlined,
                  label: loc.debts,
                  color: theme.colorScheme.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DebtsListScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          SectionCard(
            padding: EdgeInsets.zero,
            child: _MoreTile(
              icon: Icons.settings_outlined,
              label: loc.settings,
              color: theme.colorScheme.primary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: TintedIcon(icon: icon, color: color),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
