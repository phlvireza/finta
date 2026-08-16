import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/account_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/number_utils.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import '../../widgets/tinted_icon.dart';
import '../../widgets/form_sheet.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/account_form.dart';

/// Screen to list, create, edit, and archive accounts.
class ManageAccountsScreen extends StatelessWidget {
  const ManageAccountsScreen({super.key});

  static void showAccountForm(BuildContext context, {AccountModel? account}) {
    FormSheet.show(
      context,
      builder: (_) => AccountForm(accountToEdit: account),
    );
  }

  Future<void> _archiveAccount(BuildContext context, AccountModel account) async {
    final loc = AppLocalizations.of(context)!;
    final provider = context.read<AccountProvider>();
    final usage = await provider.countUsage(account.id);
    if (!context.mounted) return;

    if (usage > 0) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: loc.archiveAccount,
        message: loc.confirmArchiveAccount(account.name, usage),
        confirmText: loc.archive,
      );
      if (confirmed) await provider.archiveAccount(account.id);
    } else {
      final confirmed = await ConfirmDialog.show(
        context,
        title: loc.archiveAccount,
        message: loc.confirmArchiveAccountUnused(account.name),
        confirmText: loc.archive,
      );
      if (confirmed) await provider.archiveAccount(account.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final provider = context.watch<AccountProvider>();
    final settings = context.watch<SettingsProvider>();
    final accounts = provider.activeAccounts;

    return Scaffold(
      appBar: AppBar(title: Text(loc.manageAccounts)),
      body: accounts.isEmpty
          ? EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: loc.noAccountsYet,
              subtitle: loc.noAccountsYetMessage,
              action: ElevatedButton(
                onPressed: () => showAccountForm(context),
                child: Text(loc.addAccount),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.fabClearance,
              ),
              children: [
                SectionCard(
                  title: loc.netWorth,
                  trailing: Text(
                    NumberUtils.formatCurrency(
                      provider.netWorth,
                      symbol: settings.currencySymbol,
                      useDecimals: settings.currencyUseDecimals,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final account in accounts) ...[
                        if (account != accounts.first) const Divider(),
                        ListTile(
                          leading: TintedIcon(icon: account.iconData, color: account.colorValue),
                          title: Text(account.name),
                          subtitle: Text(
                            account.isCreditCard && provider.balanceOf(account.id) < 0
                                ? loc.amountOwed(NumberUtils.formatCurrency(
                                    -provider.balanceOf(account.id),
                                    symbol: settings.currencySymbol,
                                    useDecimals: settings.currencyUseDecimals,
                                  ))
                                : NumberUtils.formatCurrency(
                                    provider.balanceOf(account.id),
                                    symbol: settings.currencySymbol,
                                    useDecimals: settings.currencyUseDecimals,
                                  ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                showAccountForm(context, account: account);
                              } else if (value == 'archive') {
                                _archiveAccount(context, account);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(loc.edit)),
                              PopupMenuItem(value: 'archive', child: Text(loc.archive)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => showAccountForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
