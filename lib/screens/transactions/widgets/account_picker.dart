import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/account_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../accounts/widgets/account_form.dart';

/// Form field that opens a bottom sheet for account selection — same shape
/// as [CategoryPicker] so the two fields read consistently on the entry
/// form, but simpler since accounts don't need search (there are rarely
/// more than a handful).
class AccountPicker extends StatelessWidget {
  final String label;
  final String? selectedAccountId;
  final ValueChanged<String> onAccountSelected;
  final List<String> excludeIds;
  final FormFieldValidator<String>? validator;

  const AccountPicker({
    super.key,
    required this.label,
    required this.selectedAccountId,
    required this.onAccountSelected,
    this.excludeIds = const [],
    this.validator,
  });

  void _openAccountSheet(BuildContext context, FormFieldState<String> state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountSheet(
        selectedAccountId: selectedAccountId,
        excludeIds: excludeIds,
        onSelected: (id) {
          state.didChange(id);
          onAccountSelected(id);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsProvider = context.watch<AccountProvider>();
    AccountModel? selected;
    try {
      selected = accountsProvider.activeAccounts.firstWhere((a) => a.id == selectedAccountId);
    } catch (_) {}

    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: AppConstants.spacingSm),
          FormField<String>(
            validator: validator,
            initialValue: selectedAccountId,
            builder: (FormFieldState<String> state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openAccountSheet(context, state),
                    child: Container(
                      padding: const EdgeInsets.all(AppConstants.spacingMd),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        border: Border.all(
                          color: state.hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (selected != null) ...[
                            Icon(selected.iconData, color: selected.colorValue, size: 24),
                            const SizedBox(width: AppConstants.spacingMd),
                            Expanded(
                              child: Text(selected.name, style: theme.textTheme.bodyLarge),
                            ),
                          ] else ...[
                            Expanded(
                              child: Text(
                                loc.selectAnAccount,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ),
                          ],
                          Icon(Icons.keyboard_arrow_down, color: theme.iconTheme.color),
                        ],
                      ),
                    ),
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: AppConstants.spacingXs),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
                      child: Text(
                        state.errorText!,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountSheet extends StatelessWidget {
  final String? selectedAccountId;
  final List<String> excludeIds;
  final ValueChanged<String> onSelected;

  const _AccountSheet({
    required this.selectedAccountId,
    required this.excludeIds,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsProvider = context.watch<AccountProvider>();
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context)!;
    final accounts = accountsProvider.activeAccounts
        .where((a) => !excludeIds.contains(a.id))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        top: AppConstants.spacingLg,
        left: AppConstants.spacingLg,
        right: AppConstants.spacingLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppConstants.spacingLg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: theme.colorScheme.onSecondary),
              ),
              title: Text(
                loc.addAccount,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const AccountForm(),
                );
              },
            ),
            const Divider(),
            ...accounts.map((a) {
              final isSelected = a.id == selectedAccountId;
              return ListTile(
                leading: Icon(a.iconData, color: a.colorValue),
                title: Text(a.name),
                subtitle: Text(
                  NumberUtils.formatCurrency(
                    accountsProvider.balanceOf(a.id),
                    symbol: settings.currencySymbol,
                    useDecimals: settings.currencyUseDecimals,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                onTap: () => onSelected(a.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}
