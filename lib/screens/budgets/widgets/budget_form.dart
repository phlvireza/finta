import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/budget_model.dart';
import '../../transactions/widgets/amount_input_field.dart';
import '../../transactions/widgets/category_picker.dart';
import '../../../l10n/app_localizations.dart';

/// Form for creating or editing a budget.
class BudgetForm extends StatefulWidget {
  final String? budgetIdToEdit;

  const BudgetForm({super.key, this.budgetIdToEdit});

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedCategoryId;
  BudgetModel? _editingBudget;
  bool _autoValidate = false;

  @override
  void initState() {
    super.initState();
    if (widget.budgetIdToEdit != null) {
      // Find the budget being edited
      final budgets = context.read<BudgetProvider>().budgets;
      try {
        _editingBudget = budgets.firstWhere((b) => b.id == widget.budgetIdToEdit);
        _selectedCategoryId = _editingBudget!.categoryId;
        final settings = context.read<SettingsProvider>();
        _amountController.text = formatAmount(_editingBudget!.amount, useDecimals: settings.currencyUseDecimals);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<BudgetProvider>();
    final settings = context.read<SettingsProvider>();
    final amount = parseFormattedAmount(_amountController.text);
    final loc = AppLocalizations.of(context)!;

    try {
      if (_editingBudget != null) {
        await provider.updateBudget(_editingBudget!.copyWith(
          categoryId: _selectedCategoryId,
          amount: amount,
        ));
      } else {
        await provider.addBudget(
          categoryId: _selectedCategoryId!,
          amount: amount,
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
    final settings = context.watch<SettingsProvider>();
    final categories = context.watch<CategoryProvider>().expenseCategories;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingBudget != null ? loc.editBudget : loc.newBudget,
              style: theme.textTheme.titleLarge,
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

            CategoryPicker(
              isIncome: false,
              selectedCategoryId: _selectedCategoryId,
              onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
              validator: (val) {
                if (val == null) return loc.pleaseSelectCategory;
                if (_editingBudget == null) {
                  final provider = context.read<BudgetProvider>();
                  final existing = provider.budgets.any((b) => b.categoryId == val);
                  if (existing) return loc.budgetAlreadyExistsForCategory;
                }
                return null;
              },
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
    );
  }
}
