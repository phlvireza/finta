import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../accounts/manage_accounts_screen.dart';
import '../budgets/manage_budgets_screen.dart';
import '../categories/manage_categories_screen.dart';
import '../recurring/recurring_list_screen.dart';
import '../goals/goals_list_screen.dart';
import '../debts/debts_list_screen.dart';
import '../settings/settings_screen.dart';
import '../../l10n/app_localizations.dart';

/// Hub for the lower-frequency configuration surfaces — budgets,
/// categories, recurring transactions, and settings (which itself hosts
/// currency, theme, payday, and data export). Keeping these off the main
/// tab bar means the four primary destinations (Home, Records, +,
/// Insights) stay one tap away, and every surface here is reachable from
/// anywhere in the app instead of only from the dashboard.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.more)),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        children: [
          _MoreCard(
            children: [
              _MoreTile(
                icon: Icons.account_balance_wallet_outlined,
                label: loc.accounts,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageAccountsScreen()),
                ),
              ),
              const Divider(),
              _MoreTile(
                icon: Icons.track_changes,
                label: loc.budgets,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageBudgetsScreen()),
                ),
              ),
              const Divider(),
              _MoreTile(
                icon: Icons.category_outlined,
                label: loc.categories,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
                ),
              ),
              const Divider(),
              _MoreTile(
                icon: Icons.repeat,
                label: loc.recurring,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecurringListScreen()),
                ),
              ),
              const Divider(),
              _MoreTile(
                icon: Icons.savings_outlined,
                label: loc.goals,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalsListScreen()),
                ),
              ),
              const Divider(),
              _MoreTile(
                icon: Icons.handshake_outlined,
                label: loc.debts,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebtsListScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXxxl),
          _MoreCard(
            children: [
              _MoreTile(
                icon: Icons.settings_outlined,
                label: loc.settings,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  final List<Widget> children;

  const _MoreCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Column(children: children),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
