import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../add_transaction_screen.dart';
import 'amount_input_field.dart';
import 'category_picker.dart';
import 'date_picker_field.dart';
import 'type_toggle.dart';

/// Three-tap entry sheet opened from the FAB — amount, category, date,
/// save. Covers the common case fast; anything less common (recurring,
/// notes, editing) stays on the full [AddTransactionScreen].
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const QuickAddSheet(),
    );
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _amountController = TextEditingController();
  bool _isIncome = false;
  DateTime _date = DateTime.now();
  String? _categoryId;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefillMostRecentCategory();
  }

  void _prefillMostRecentCategory() {
    final recent = context.read<TransactionProvider>().recentTransactions;
    for (final tx in recent) {
      if (tx.isIncome == _isIncome) {
        _categoryId = tx.categoryId;
        break;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _toggleType(bool isIncome) {
    if (_isIncome == isIncome) return;
    setState(() {
      _isIncome = isIncome;
      _categoryId = null;
      _prefillMostRecentCategory();
    });
  }

  Future<void> _openFullForm() {
    Navigator.of(context).pop();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    final amount = parseFormattedAmount(_amountController.text);

    if (amount <= 0) {
      setState(() => _error = loc.pleaseEnterValidAmount);
      return;
    }
    if (_categoryId == null) {
      setState(() => _error = loc.pleaseSelectCategory);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final txProvider = context.read<TransactionProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final settings = context.read<SettingsProvider>();

      await txProvider.addTransaction(
        type: _isIncome ? 'income' : 'expense',
        amount: amount,
        categoryId: _categoryId!,
        date: _date,
      );

      await txProvider.loadTransactions(payday: settings.payday);
      await budgetProvider.loadBudgets(payday: settings.payday);
      if (mounted) {
        await context.read<AnalyticsProvider>().loadForCurrentPeriod(settings.payday);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = loc.errorFailedToSave;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppConstants.spacingSm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              child: TypeToggle(
                isIncome: _isIncome,
                onChanged: _toggleType,
                expenseLabel: loc.expense,
                incomeLabel: loc.income,
              ),
            ),
            AmountInputField(
              controller: _amountController,
              isIncome: _isIncome,
              autofocus: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              child: DatePickerField(
                selectedDate: _date,
                onDateSelected: (date) => setState(() => _date = date),
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            CategoryPicker(
              isIncome: _isIncome,
              selectedCategoryId: _categoryId,
              onCategorySelected: (id) => setState(() {
                _categoryId = id;
                _error = null;
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppConstants.spacingSm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: AppConstants.spacingLg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSaving ? null : _openFullForm,
                      child: Text(loc.moreOptions),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isIncome
                                    ? (theme.brightness == Brightness.dark
                                        ? AppColors.darkIncome
                                        : AppColors.lightIncome)
                                    : (theme.brightness == Brightness.dark
                                        ? AppColors.darkExpense
                                        : AppColors.lightExpense),
                              ),
                              child: Text(loc.saveTransaction),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
          ],
        ),
      ),
    );
  }
}
