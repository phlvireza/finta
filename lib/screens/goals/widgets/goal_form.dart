import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/goal_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';

/// Form for creating or editing a savings goal.
class GoalForm extends StatefulWidget {
  final GoalModel? goalToEdit;

  const GoalForm({super.key, this.goalToEdit});

  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  String _selectedColor = '#5B8C5A';
  DateTime? _targetDate;
  bool _autoValidate = false;
  bool _isSaving = false;

  final List<String> _colorOptions = const [
    '#5B8C5A', '#C87941', '#6F8B8A', '#C2665A', '#D4A05A',
    '#7A8B6F', '#B07A5B', '#8B6F7A', '#CBA882', '#8A6E5E',
  ];

  @override
  void initState() {
    super.initState();
    final goal = widget.goalToEdit;
    if (goal != null) {
      _nameController.text = goal.name;
      _selectedColor = goal.color;
      _targetDate = goal.targetDate;
      final settings = context.read<SettingsProvider>();
      _targetAmountController.text = formatAmount(
        goal.targetAmount,
        useDecimals: settings.currencyUseDecimals,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final loc = AppLocalizations.of(context)!;
    final provider = context.read<GoalProvider>();
    final name = _nameController.text.trim();
    final targetAmount = parseFormattedAmount(_targetAmountController.text);

    try {
      if (widget.goalToEdit != null) {
        final updated = widget.goalToEdit!.copyWith(
          name: name,
          targetAmount: targetAmount,
          targetDate: _targetDate,
          clearTargetDate: _targetDate == null,
          color: _selectedColor,
        );
        await provider.updateGoal(updated);
      } else {
        await provider.addGoal(
          name: name,
          targetAmount: targetAmount,
          targetDate: _targetDate,
          color: _selectedColor,
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
                widget.goalToEdit != null ? loc.editGoal : loc.addGoal,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppConstants.spacingXxl),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: loc.goalName,
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
              TextFormField(
                controller: _targetAmountController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  labelText: loc.targetAmount,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  final amount = parseFormattedAmount(val ?? '');
                  return amount <= 0 ? loc.pleaseEnterValidAmount : null;
                },
              ),
              const SizedBox(height: AppConstants.spacingLg),
              Text(loc.targetDateOptional, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppConstants.spacingSm),
              InkWell(
                onTap: _pickTargetDate,
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
                      Text(
                        _targetDate != null ? AppDateUtils.formatFull(_targetDate!) : loc.noDateSet,
                      ),
                      const Spacer(),
                      if (_targetDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _targetDate = null),
                        ),
                    ],
                  ),
                ),
              ),
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
