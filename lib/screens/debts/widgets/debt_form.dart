import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/debt_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/keypad_amount_field.dart';

/// Form for creating or editing a debt (money lent to, or borrowed from,
/// someone). The principal is fixed here; repayments are logged separately
/// as ordinary transactions (see RepaymentSheet).
class DebtForm extends StatefulWidget {
  final DebtModel? debtToEdit;

  const DebtForm({super.key, this.debtToEdit});

  @override
  State<DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<DebtForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _noteController = TextEditingController();
  String _type = 'borrowed';
  DateTime? _dueDate;
  bool _autoValidate = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final debt = widget.debtToEdit;
    if (debt != null) {
      _nameController.text = debt.name;
      _type = debt.type;
      _dueDate = debt.dueDate;
      _noteController.text = debt.note ?? '';
      final settings = context.read<SettingsProvider>();
      _principalController.text = formatAmount(debt.principal, useDecimals: settings.currencyUseDecimals);
      if (debt.interestRate != null) {
        _interestController.text = (debt.interestRate! * 100).toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final loc = AppLocalizations.of(context)!;
    final provider = context.read<DebtProvider>();
    final name = _nameController.text.trim();
    final principal = parseFormattedAmount(_principalController.text);
    final interestRate = _interestController.text.trim().isEmpty
        ? null
        : (double.tryParse(_interestController.text.trim()) ?? 0) / 100;
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    try {
      if (widget.debtToEdit != null) {
        final updated = widget.debtToEdit!.copyWith(
          name: name,
          type: _type,
          principal: principal,
          dueDate: _dueDate,
          clearDueDate: _dueDate == null,
          interestRate: interestRate,
          clearInterestRate: interestRate == null,
          note: note,
          clearNote: note == null,
        );
        await provider.updateDebt(updated);
      } else {
        await provider.addDebt(
          name: name,
          type: _type,
          principal: principal,
          dueDate: _dueDate,
          interestRate: interestRate,
          note: note,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.errorFailedToSave)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

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
                widget.debtToEdit != null ? loc.editDebt : loc.addDebt,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppConstants.spacingXxl),
              Wrap(
                spacing: AppConstants.spacingSm,
                children: [
                  ChoiceChip(
                    label: Text(loc.debtTypeBorrowed),
                    selected: _type == 'borrowed',
                    onSelected: (_) => setState(() => _type = 'borrowed'),
                  ),
                  ChoiceChip(
                    label: Text(loc.debtTypeLent),
                    selected: _type == 'lent',
                    onSelected: (_) => setState(() => _type = 'lent'),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _type == 'borrowed' ? loc.borrowedFrom : loc.lentTo,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
                textCapitalization: TextCapitalization.words,
                maxLength: 40,
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? loc.pleaseEnterName : null,
              ),
              const SizedBox(height: AppConstants.spacingLg),
              KeypadAmountField(
                controller: _principalController,
                labelText: loc.principalAmount,
                validator: requiredAmountValidator(loc),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              TextFormField(
                controller: _interestController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: loc.interestRateOptional,
                  suffixText: '% / mo',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              Text(loc.dueDateOptional, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppConstants.spacingSm),
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: theme.iconTheme.color),
                      const SizedBox(width: AppConstants.spacingMd),
                      Text(_dueDate != null ? AppDateUtils.formatFull(_dueDate!) : loc.noDateSet),
                      const Spacer(),
                      if (_dueDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _dueDate = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: loc.noteOptional,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
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
