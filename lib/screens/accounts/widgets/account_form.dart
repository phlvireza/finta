import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/account_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/keypad_amount_field.dart';

/// Form for creating or editing an account.
class AccountForm extends StatefulWidget {
  final AccountModel? accountToEdit;

  const AccountForm({super.key, this.accountToEdit});

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _creditLimitController = TextEditingController();
  String _type = 'cash';
  String _selectedColor = '#C87941';
  bool _includeInTotal = true;
  bool _autoValidate = false;
  bool _isSaving = false;

  final List<String> _colorOptions = const [
    '#C87941', '#5B8C5A', '#C2665A', '#D4A05A', '#7A8B6F',
    '#B07A5B', '#8B6F7A', '#6F8B8A', '#CBA882', '#8A6E5E',
  ];

  @override
  void initState() {
    super.initState();
    final account = widget.accountToEdit;
    if (account != null) {
      _nameController.text = account.name;
      _type = account.type;
      _selectedColor = account.color;
      _includeInTotal = account.includeInTotal;
      final settings = context.read<SettingsProvider>();
      _openingBalanceController.text = formatAmount(
        account.openingBalance,
        useDecimals: settings.currencyUseDecimals,
      );
      if (account.creditLimit != null) {
        _creditLimitController.text = formatAmount(
          account.creditLimit!,
          useDecimals: settings.currencyUseDecimals,
        );
      }
    } else {
      _openingBalanceController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final loc = AppLocalizations.of(context)!;
    final provider = context.read<AccountProvider>();
    final name = _nameController.text.trim();
    final openingBalance = parseFormattedAmount(_openingBalanceController.text);
    final creditLimit = _type == 'credit_card' && _creditLimitController.text.isNotEmpty
        ? parseFormattedAmount(_creditLimitController.text)
        : null;

    try {
      if (widget.accountToEdit != null) {
        final updated = widget.accountToEdit!.copyWith(
          name: name,
          type: _type,
          openingBalance: openingBalance,
          color: _selectedColor,
          creditLimit: creditLimit,
          clearCreditLimit: creditLimit == null,
          includeInTotal: _includeInTotal,
        );
        await provider.updateAccount(updated);
      } else {
        await provider.addAccount(
          name: name,
          type: _type,
          openingBalance: openingBalance,
          color: _selectedColor,
          creditLimit: creditLimit,
          includeInTotal: _includeInTotal,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.errorFailedToSave)),
        );
      }
    }
  }

  String _typeLabel(AppLocalizations loc, String type) {
    switch (type) {
      case 'bank':
        return loc.accountTypeBank;
      case 'credit_card':
        return loc.accountTypeCreditCard;
      case 'e_wallet':
        return loc.accountTypeEWallet;
      case 'savings':
        return loc.accountTypeSavings;
      case 'investment':
        return loc.accountTypeInvestment;
      case 'cash':
      default:
        return loc.accountTypeCash;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final hexColor = _selectedColor.replaceAll('#', '');
    final colorValue = Color(int.parse('FF$hexColor', radix: 16));

    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.spacingLg,
        right: AppConstants.spacingLg,
        top: AppConstants.spacingLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppConstants.spacingLg,
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: _autoValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.accountToEdit != null ? loc.editAccount : loc.addAccount,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorValue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      border: Border.all(color: colorValue),
                    ),
                    child: Icon(AccountModel.iconForType(_type), color: colorValue),
                  ),
                  const SizedBox(width: AppConstants.spacingLg),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: loc.accountName,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 30,
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? loc.pleaseEnterName : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              Text(loc.accountType, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: AppConstants.spacingSm,
                runSpacing: AppConstants.spacingSm,
                children: AccountModel.types.map((type) {
                  final isSelected = type == _type;
                  return ChoiceChip(
                    label: Text(_typeLabel(loc, type)),
                    avatar: Icon(AccountModel.iconForType(type), size: 18),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _type = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              KeypadAmountField(
                controller: _openingBalanceController,
                labelText: loc.openingBalance,
                validator: optionalAmountValidator(loc),
              ),

              if (_type == 'credit_card') ...[
                const SizedBox(height: AppConstants.spacingLg),
                KeypadAmountField(
                  controller: _creditLimitController,
                  labelText: loc.creditLimitOptional,
                  validator: optionalAmountValidator(loc),
                ),
              ],
              const SizedBox(height: AppConstants.spacingXxl),

              Text(loc.color, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppConstants.spacingMd),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorOptions.length,
                  separatorBuilder: (context, _) => const SizedBox(width: AppConstants.spacingMd),
                  itemBuilder: (context, index) {
                    final hex = _colorOptions[index];
                    final c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                    final isSelected = hex == _selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = hex),
                      child: Container(
                        width: 48,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                              : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(loc.includeInTotal),
                subtitle: Text(loc.includeInTotalDescription),
                value: _includeInTotal,
                onChanged: (val) => setState(() => _includeInTotal = val),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _save, child: Text(loc.save)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
