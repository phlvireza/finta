import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../models/budget_model.dart';
import '../../transactions/widgets/amount_input_field.dart';
import '../../transactions/widgets/category_picker.dart';
import '../../../l10n/app_localizations.dart';

/// Form for creating or editing a budget — a single category, a named
/// group of categories, or an overall cap across every expense category;
/// with a period length and an optional rollover mode.
class BudgetForm extends StatefulWidget {
  final String? budgetIdToEdit;

  const BudgetForm({super.key, this.budgetIdToEdit});

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  String? _selectedCategoryId;
  Set<String> _selectedCategoryIds = {};
  String _scope = 'category';
  String _period = 'monthly';
  String _rolloverMode = 'none';
  BudgetModel? _editingBudget;
  bool _autoValidate = false;

  @override
  void initState() {
    super.initState();
    if (widget.budgetIdToEdit != null) {
      final budgets = context.read<BudgetProvider>().budgets;
      try {
        _editingBudget = budgets.firstWhere((b) => b.id == widget.budgetIdToEdit);
        _scope = _editingBudget!.scope;
        _period = _editingBudget!.period;
        _rolloverMode = _editingBudget!.rolloverMode;
        _nameController.text = _editingBudget!.name ?? '';
        _selectedCategoryIds = _editingBudget!.categoryIds.toSet();
        _selectedCategoryId =
            _editingBudget!.categoryIds.isNotEmpty ? _editingBudget!.categoryIds.first : null;
        final settings = context.read<SettingsProvider>();
        _amountController.text = formatAmount(_editingBudget!.amount, useDecimals: settings.currencyUseDecimals);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool _categoryAlreadyBudgeted(String categoryId) {
    final provider = context.read<BudgetProvider>();
    return provider.budgets.any(
      (b) => b.id != _editingBudget?.id && b.isActive && b.categoryIds.contains(categoryId),
    );
  }

  Future<void> _save() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_scope == 'category' && _selectedCategoryId == null) return;
    if (_scope == 'group' && _selectedCategoryIds.length < 2) return;

    final provider = context.read<BudgetProvider>();
    final settings = context.read<SettingsProvider>();
    final amount = parseFormattedAmount(_amountController.text);
    final loc = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final categoryIds = _scope == 'category'
        ? [_selectedCategoryId!]
        : _scope == 'group'
            ? _selectedCategoryIds.toList()
            : <String>[];

    try {
      if (_editingBudget != null) {
        await provider.updateBudget(
          _editingBudget!.copyWith(
            name: name.isEmpty ? null : name,
            clearName: name.isEmpty,
            amount: amount,
            period: _period,
            rolloverMode: _rolloverMode,
            scope: _scope,
            categoryIds: categoryIds,
          ),
          payday: settings.payday,
        );
      } else {
        await provider.addBudget(
          name: name.isEmpty ? null : name,
          amount: amount,
          period: _period,
          rolloverMode: _rolloverMode,
          scope: _scope,
          categoryIds: categoryIds,
          payday: settings.payday,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
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
                _editingBudget != null ? loc.editBudget : loc.newBudget,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              Text(loc.budgetScope, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: AppConstants.spacingSm,
                children: [
                  ChoiceChip(
                    label: Text(loc.budgetScopeCategory),
                    selected: _scope == 'category',
                    onSelected: (_) => setState(() => _scope = 'category'),
                  ),
                  ChoiceChip(
                    label: Text(loc.budgetScopeGroup),
                    selected: _scope == 'group',
                    onSelected: (_) => setState(() => _scope = 'group'),
                  ),
                  ChoiceChip(
                    label: Text(loc.budgetScopeOverall),
                    selected: _scope == 'overall',
                    onSelected: (_) => setState(() => _scope = 'overall'),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              AmountInputField(
                controller: _amountController,
                isIncome: false, // Budgets use expense colors
                labelOverride: loc.budgetAmount,
                validator: (val) {
                  final amount = parseFormattedAmount(val ?? '');
                  if (amount <= 0 || amount > 999999999999) return loc.pleaseEnterValidAmount;
                  return null;
                },
              ),

              if (_scope != 'category') ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _scope == 'overall' ? loc.budgetNameOptional : loc.budgetName,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) {
                      if (_scope == 'group' && (val == null || val.trim().isEmpty)) {
                        return loc.pleaseEnterName;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXxl),
              ],

              if (_scope == 'category')
                CategoryPicker(
                  isIncome: false,
                  selectedCategoryId: _selectedCategoryId,
                  onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
                  validator: (val) {
                    if (val == null) return loc.pleaseSelectCategory;
                    if (_categoryAlreadyBudgeted(val)) return loc.budgetAlreadyExistsForCategory;
                    return null;
                  },
                )
              else if (_scope == 'group')
                _GroupCategoryPicker(
                  selected: _selectedCategoryIds,
                  onChanged: (ids) => setState(() => _selectedCategoryIds = ids),
                  isAlreadyBudgeted: _categoryAlreadyBudgeted,
                ),
              const SizedBox(height: AppConstants.spacingXxl),

              Text(loc.budgetPeriod, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: AppConstants.spacingSm,
                children: [
                  ChoiceChip(
                    label: Text(loc.weekly),
                    selected: _period == 'weekly',
                    onSelected: (_) => setState(() => _period = 'weekly'),
                  ),
                  ChoiceChip(
                    label: Text(loc.monthly),
                    selected: _period == 'monthly',
                    onSelected: (_) => setState(() => _period = 'monthly'),
                  ),
                  ChoiceChip(
                    label: Text(loc.quarter),
                    selected: _period == 'quarterly',
                    onSelected: (_) => setState(() => _period = 'quarterly'),
                  ),
                  ChoiceChip(
                    label: Text(loc.year),
                    selected: _period == 'yearly',
                    onSelected: (_) => setState(() => _period = 'yearly'),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              Text(loc.budgetRollover, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppConstants.spacingXs),
              Text(
                loc.budgetRolloverExplanation,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: AppConstants.spacingSm,
                children: [
                  ChoiceChip(
                    label: Text(loc.rolloverNone),
                    selected: _rolloverMode == 'none',
                    onSelected: (_) => setState(() => _rolloverMode = 'none'),
                  ),
                  ChoiceChip(
                    label: Text(loc.rolloverPositiveOnly),
                    selected: _rolloverMode == 'positive',
                    onSelected: (_) => setState(() => _rolloverMode = 'positive'),
                  ),
                  ChoiceChip(
                    label: Text(loc.rolloverFull),
                    selected: _rolloverMode == 'full',
                    onSelected: (_) => setState(() => _rolloverMode = 'full'),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingXxxl),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(loc.saveBudget),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCategoryPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool Function(String categoryId) isAlreadyBudgeted;

  const _GroupCategoryPicker({
    required this.selected,
    required this.onChanged,
    required this.isAlreadyBudgeted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final categories = context.watch<CategoryProvider>().expenseCategories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.selectAtLeastTwoCategories, style: theme.textTheme.labelMedium),
          const SizedBox(height: AppConstants.spacingSm),
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingSm,
            children: categories.map((c) {
              final alreadyUsed = !selected.contains(c.id) && isAlreadyBudgeted(c.id);
              return FilterChip(
                label: Text(c.name),
                avatar: Icon(c.iconData, size: 16, color: c.colorValue),
                selected: selected.contains(c.id),
                onSelected: alreadyUsed
                    ? null
                    : (isSelected) {
                        final updated = Set<String>.from(selected);
                        if (isSelected) {
                          updated.add(c.id);
                        } else {
                          updated.remove(c.id);
                        }
                        onChanged(updated);
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
