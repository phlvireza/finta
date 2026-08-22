import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/insights_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/currency_formatter.dart';
import '../../core/utils/number_utils.dart';
import '../../widgets/amount_input_field.dart';
import '../../widgets/amount_keypad.dart';
import 'widgets/category_picker.dart';
import 'widgets/account_picker.dart';
import 'widgets/merchant_field.dart';
import 'widgets/date_picker_field.dart';
import 'widgets/recurring_toggle.dart';
import 'widgets/type_toggle.dart';
import 'widgets/anomaly_confirm.dart';
import 'widgets/save_template_dialog.dart';
import '../../l10n/app_localizations.dart';

/// Full-screen form for adding or editing a transaction.
class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? editTransaction;

  const AddTransactionScreen({super.key, this.editTransaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isIncome;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _date;
  String? _categoryId;
  String? _accountId;
  String? _merchant;

  bool _isRecurring = false;
  String _recurringFrequency = 'monthly';
  bool _isSubscription = false;

  bool _isSaving = false;
  bool _autoValidate = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.editTransaction;
    _isIncome = tx?.isIncome ?? false;

    // We format the amount without symbols for the input field
    final settings = context.read<SettingsProvider>();
    final initialAmount = tx != null ? formatAmount(tx.amount, useDecimals: settings.currencyUseDecimals) : '';
    _amountController = TextEditingController(text: initialAmount);
    _noteController = TextEditingController(text: tx?.note ?? '');
    _date = tx?.date ?? DateTime.now();
    _categoryId = tx?.categoryId;
    _accountId = tx?.accountId ?? _mostRecentAccountId();
    _merchant = tx?.merchant;

    if (tx != null && tx.isRecurring) {
      _isRecurring = true;
    }
  }

  /// Defaults the account picker to whatever account the user's most
  /// recent transaction used. The category picker deliberately gets no
  /// equivalent default — see [MerchantField] for why.
  String? _mostRecentAccountId() {
    final recent = context.read<TransactionProvider>().recentTransactions;
    if (recent.isNotEmpty) return recent.first.accountId;
    final accounts = context.read<AccountProvider>().activeAccounts;
    return accounts.isNotEmpty ? accounts.first.id : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _toggleType(bool isIncome) {
    if (_isIncome == isIncome) return;
    setState(() {
      _isIncome = isIncome;
      _categoryId = null; // Reset category selection
    });
  }

  Future<void> _save() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final loc = AppLocalizations.of(context)!;
    final amount = parseFormattedAmount(_amountController.text);

    // A statistical-outlier nudge, not a hard block — only for a brand-new
    // expense, where there's a category chosen to check history against.
    if (widget.editTransaction == null && !_isIncome && _categoryId != null) {
      final check = await context.read<InsightsProvider>().checkAnomaly(_categoryId!, amount);
      if (!mounted) return;
      if (check != null && check.isAnomaly) {
        final categoryName = context.read<CategoryProvider>().getCategoryById(_categoryId!)?.name ?? loc.unknown;
        final settings = context.read<SettingsProvider>();
        final proceed = await confirmUnusualAmount(
          context,
          loc: loc,
          categoryName: categoryName,
          formattedAmount: NumberUtils.formatCurrency(amount, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
          formattedTypical: NumberUtils.formatCurrency(check.mean, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
        );
        if (!proceed || !mounted) return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final txProvider = context.read<TransactionProvider>();
      final recurringProvider = context.read<RecurringProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final settings = context.read<SettingsProvider>();

      String type = _isIncome ? 'income' : 'expense';
      String? recurringId = widget.editTransaction?.recurringId;

      final trimmedMerchant = _merchant?.trim();
      final merchant = (trimmedMerchant == null || trimmedMerchant.isEmpty) ? null : trimmedMerchant;

      // Create recurring template if new and toggled
      if (widget.editTransaction == null && _isRecurring) {
        final recTx = await recurringProvider.addRecurring(
          type: type,
          amount: amount,
          categoryId: _categoryId!,
          accountId: _accountId,
          merchant: merchant,
          note: _noteController.text.trim(),
          frequency: _recurringFrequency,
          startDate: _date,
          isSubscription: _isSubscription,
        );
        recurringId = recTx.id;
      }

      if (widget.editTransaction != null) {
        // Update existing
        final updated = widget.editTransaction!.copyWith(
          type: type,
          amount: amount,
          categoryId: _categoryId,
          accountId: _accountId,
          merchant: merchant,
          date: _date,
          note: _noteController.text.trim(),
        );
        await txProvider.updateTransaction(updated);
      } else {
        // Add new
        await txProvider.addTransaction(
          type: type,
          amount: amount,
          categoryId: _categoryId!,
          accountId: _accountId!,
          merchant: merchant,
          date: _date,
          note: _noteController.text.trim(),
          recurringId: recurringId,
        );

        // Check budget if expense
        if (!_isIncome) {
          final alert = budgetProvider.checkBudgetAlert(_categoryId!, amount, settings.payday);
          if (alert != null && mounted) {
            String message = '';
            if (alert.type == BudgetAlertType.exceeded) {
              message = AppLocalizations.of(context)!.budgetExceededAlert;
            } else if (alert.type == BudgetAlertType.warning) {
              message = AppLocalizations.of(context)!.budgetWarningAlert(alert.percentage);
            }

            if (message.isNotEmpty) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: AppColors.warning,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      }

      // Refresh all providers so the UI reflects the new or updated transaction
      await txProvider.loadTransactions(payday: settings.payday);
      await budgetProvider.loadBudgets(payday: settings.payday);
      if (mounted) {
        await context.read<AnalyticsProvider>().loadForCurrentPeriod(settings.payday);
      }
      if (mounted) {
        await context.read<AccountProvider>().loadAccounts();
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorFailedToSave)),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  /// Saves the form's current values as a one-tap quick-add template.
  /// Only offered for a brand-new entry — templating an edit-in-progress
  /// would be an odd, easy-to-mispress action next to Save.
  Future<void> _saveAsTemplate() {
    return saveAsTemplate(
      context,
      isIncome: _isIncome,
      amount: parseFormattedAmount(_amountController.text),
      categoryId: _categoryId,
      accountId: _accountId,
      merchant: _merchant,
      note: _noteController.text,
    );
  }

  void _showTemplateInfo(BuildContext context, AppLocalizations loc) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.saveAsTemplate),
        content: Text(loc.saveAsTemplateHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.gotIt),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.editTransaction != null;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? loc.editTransaction : loc.addTransaction),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!isEditing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: loc.saveAsTemplate,
                  onPressed: _saveAsTemplate,
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                  onTap: () => _showTemplateInfo(context, loc),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary.withAlpha(180),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppConstants.spacingLg,
            right: AppConstants.spacingLg,
            // The amount opens a full-screen sheet rather than the OS
            // keyboard, but the note and merchant fields still do.
            bottom: AppConstants.spacingLg + MediaQuery.of(context).viewInsets.bottom,
            top: AppConstants.spacingSm,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: _isSaving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _save,
                    child: Text(isEditing ? loc.saveChanges : loc.saveTransaction),
                  ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // Type toggle
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
                // The field is a tap target for the full-screen keypad
                // sheet now, not something the OS keyboard can autofocus
                // into — opening that sheet the instant the screen appears
                // would cover the form before the user has seen it, so
                // entry now waits for an explicit tap either way.
                onKeypadRequested: () => AmountKeypad.show(
                  context,
                  controller: _amountController,
                  isIncome: _isIncome,
                ),
                validator: (val) {
                  final amount = parseFormattedAmount(val ?? '');
                  if (amount <= 0 || amount > AppConstants.maxAmount) {
                    return loc.pleaseEnterValidAmount;
                  }
                  return null;
                },
              ),

              // Field order below is deliberately identical to QuickAddSheet:
              // date, account, merchant, category. This screen handles both
              // creating and editing, and the sheet handles the FAB create, so
              // any divergence means the same user meets two different layouts
              // for the same task. Merchant used to sit directly under the
              // amount here; it was moved down to match the sheet.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                child: DatePickerField(
                  selectedDate: _date,
                  onDateSelected: (date) => setState(() => _date = date),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              AccountPicker(
                label: loc.account,
                selectedAccountId: _accountId,
                onAccountSelected: (id) => setState(() => _accountId = id),
                validator: (val) => val == null ? loc.selectAnAccount : null,
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              MerchantField(
                initialValue: _merchant,
                onChanged: (val) => _merchant = val,
                onAccountDefault: (accountId) => setState(() => _accountId = accountId),
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              CategoryPicker(
                isIncome: _isIncome,
                selectedCategoryId: _categoryId,
                onCategorySelected: (id) => setState(() => _categoryId = id),
                validator: (val) {
                  if (val == null) return loc.pleaseSelectCategory;
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.noteOptional, style: theme.textTheme.labelMedium),
                    const SizedBox(height: AppConstants.spacingSm),
                    TextField(
                      controller: _noteController,
                      maxLength: AppConstants.maxNoteLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: '',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXl),

                    // Only show recurring toggle for new transactions
                    if (!isEditing) ...[
                      RecurringToggle(
                        isRecurring: _isRecurring,
                        onToggle: (val) => setState(() {
                          _isRecurring = val;
                          if (!val) _isSubscription = false;
                        }),
                        frequency: _recurringFrequency,
                        onFrequencyChanged: (val) => setState(() => _recurringFrequency = val),
                        isSubscription: _isSubscription,
                        onSubscriptionToggle: (val) => setState(() => _isSubscription = val),
                      ),
                      const SizedBox(height: AppConstants.spacingXxxl),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
