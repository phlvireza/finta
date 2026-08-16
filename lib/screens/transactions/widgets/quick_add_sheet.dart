import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/template_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/insights_provider.dart';
import '../../../providers/recurring_provider.dart';
import '../../../models/template_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/form_sheet.dart';
import '../../../widgets/amount_input_field.dart';
import '../../../widgets/amount_keypad.dart';
import 'category_picker.dart';
import 'account_picker.dart';
import 'merchant_field.dart';
import 'date_picker_field.dart';
import 'recurring_toggle.dart';
import 'anomaly_confirm.dart';
import 'save_template_dialog.dart';

enum _EntryType { expense, income, transfer }

/// Entry sheet opened from the FAB — amount, merchant, category, date,
/// note, optional recurrence, save. Also handles transfers, which never
/// need a category (or a note/recurrence — the model has no room for
/// either on a transfer) — just two accounts.
///
/// It used to stop at the amount/category/date trio and hand anything else
/// off to the full add screen behind a "More options" button, which
/// threw away everything already typed on the way there. The remaining
/// fields are cheap to show inline under a pinned Save, so that detour is
/// gone; the full screen is now only for editing an existing transaction.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  static Future<void> show(BuildContext context) {
    return FormSheet.show(
      context,
      builder: (_) => const QuickAddSheet(),
    );
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  _EntryType _entryType = _EntryType.expense;
  DateTime _date = DateTime.now();
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  String? _merchant;
  bool _isRecurring = false;
  String _recurringFrequency = 'monthly';
  bool _isSubscription = false;
  bool _isSaving = false;
  bool _autoValidate = false;

  /// Only for failures that belong to no single field — a save that threw,
  /// or template feedback. Field-level problems render inline on the field
  /// itself via [Form] validators, the same as [AddTransactionScreen].
  String? _error;
  String? _templateFeedback;

  bool get _isIncome => _entryType == _EntryType.income;
  bool get _isTransfer => _entryType == _EntryType.transfer;

  @override
  void initState() {
    super.initState();
    _prefillMostRecentAccount();
  }

  void _prefillMostRecentAccount() {
    final recent = context.read<TransactionProvider>().recentTransactions;
    if (recent.isNotEmpty) {
      _accountId = recent.first.accountId;
    } else {
      final accounts = context.read<AccountProvider>().activeAccounts;
      _accountId = accounts.isNotEmpty ? accounts.first.id : null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _setEntryType(_EntryType type) {
    if (_entryType == type) return;
    setState(() {
      _entryType = type;
      _error = null;
      _templateFeedback = null;
      if (type != _EntryType.transfer) {
        _categoryId = null;
      } else {
        // A transfer carries neither a note nor a recurrence, so anything
        // typed into those before switching would silently be dropped on
        // save — clear it instead of pretending it still applies.
        _toAccountId = null;
        _noteController.clear();
        _isRecurring = false;
        _isSubscription = false;
      }
    });
  }

  /// Saves the current form as a one-tap template. Uses onFeedback callback
  /// to render messages inside the sheet rather than via SnackBar — the modal
  /// bottom sheet would otherwise hide any SnackBar behind itself.
  Future<void> _saveAsTemplate() {
    return saveAsTemplate(
      context,
      isIncome: _isIncome,
      amount: parseFormattedAmount(_amountController.text),
      categoryId: _categoryId,
      accountId: _accountId,
      merchant: _merchant,
      note: _noteController.text,
      onFeedback: (message, {required isError}) => setState(() {
        if (isError) {
          _error = message;
          _templateFeedback = null;
        } else {
          _templateFeedback = message;
          _error = null;
        }
      }),
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

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;

    setState(() {
      _autoValidate = true;
      _error = null;
      _templateFeedback = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final amount = parseFormattedAmount(_amountController.text);

    // A statistical-outlier nudge, not a hard block — only for expenses,
    // which is the only case with a category to check history against.
    if (!_isTransfer && !_isIncome) {
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

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final txProvider = context.read<TransactionProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final settings = context.read<SettingsProvider>();
      final accountProvider = context.read<AccountProvider>();
      final recurringProvider = context.read<RecurringProvider>();

      if (_isTransfer) {
        await txProvider.addTransfer(
          fromAccountId: _accountId!,
          toAccountId: _toAccountId!,
          amount: amount,
          date: _date,
        );
      } else {
        final trimmedMerchant = _merchant?.trim();
        final merchant =
            (trimmedMerchant == null || trimmedMerchant.isEmpty) ? null : trimmedMerchant;
        final note = _noteController.text.trim();
        final type = _isIncome ? 'income' : 'expense';

        // Same order as AddTransactionScreen: create the template first,
        // then post this occurrence carrying its recurringId, so the
        // partial unique index on (recurringId, date) already covers today
        // and the catch-up pass can't post it a second time.
        String? recurringId;
        if (_isRecurring) {
          final template = await recurringProvider.addRecurring(
            type: type,
            amount: amount,
            categoryId: _categoryId!,
            accountId: _accountId,
            merchant: merchant,
            note: note.isEmpty ? null : note,
            frequency: _recurringFrequency,
            startDate: _date,
            isSubscription: _isSubscription,
          );
          recurringId = template.id;
        }

        await txProvider.addTransaction(
          type: type,
          amount: amount,
          categoryId: _categoryId!,
          accountId: _accountId!,
          merchant: merchant,
          date: _date,
          note: note.isEmpty ? null : note,
          recurringId: recurringId,
        );
      }

      await txProvider.loadTransactions(payday: settings.payday);
      await budgetProvider.loadBudgets(payday: settings.payday);
      await accountProvider.loadAccounts();
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

  /// Materializes a saved template into a transaction dated today and
  /// closes the sheet — the whole point of a template is skipping the
  /// rest of the form.
  Future<void> _useTemplate(TemplateModel template) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final txProvider = context.read<TransactionProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final settings = context.read<SettingsProvider>();
      final accountProvider = context.read<AccountProvider>();

      await txProvider.addTransaction(
        type: template.type,
        amount: template.amount,
        categoryId: template.categoryId,
        accountId: template.accountId,
        merchant: template.merchant,
        note: template.note,
        date: DateTime.now(),
      );

      await txProvider.loadTransactions(payday: settings.payday);
      await budgetProvider.loadBudgets(payday: settings.payday);
      await accountProvider.loadAccounts();
      if (mounted) {
        await context.read<AnalyticsProvider>().loadForCurrentPeriod(settings.payday);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = AppLocalizations.of(context)!.errorFailedToSave;
        });
      }
    }
  }

  Future<void> _deleteTemplate(BuildContext context, TemplateModel template) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await ConfirmDialog.show(
      context,
      title: loc.deleteTemplate,
      message: loc.confirmDeleteTemplate(template.name),
      confirmText: loc.delete,
    );
    if (confirmed && context.mounted) {
      await context.read<TemplateProvider>().deleteTemplate(template.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    final accentColor = _isTransfer
        ? theme.colorScheme.primary
        : (_isIncome
            ? (theme.brightness == Brightness.dark ? AppColors.darkIncome : AppColors.lightIncome)
            : (theme.brightness == Brightness.dark ? AppColors.darkExpense : AppColors.lightExpense));

    return FormSheet(
      title: _isTransfer ? loc.transfer : loc.addTransaction,
      // The only remaining way to create a template now that the sheet no
      // longer hands off to the full form.
      headerAction: _isTransfer
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: loc.saveAsTemplate,
                  onPressed: _isSaving ? null : _saveAsTemplate,
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
      action: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: accentColor),
              child: Text(loc.saveTransaction),
            ),
      body: Form(
        key: _formKey,
        autovalidateMode:
            _autoValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              child: _EntryTypeSegments(
                entryType: _entryType,
                onChanged: _setEntryType,
                expenseLabel: loc.expense,
                incomeLabel: loc.income,
                transferLabel: loc.transfer,
              ),
            ),
            if (!_isTransfer) ...[
              const SizedBox(height: AppConstants.spacingMd),
              _TemplateChipsRow(onSelected: _useTemplate, onDelete: _deleteTemplate),
            ],
            AmountInputField(
              controller: _amountController,
              isIncome: _isIncome || _isTransfer,
              labelOverride: _isTransfer ? loc.transferAmount : null,
              onKeypadRequested: () => AmountKeypad.show(
                context,
                controller: _amountController,
                isIncome: _isIncome || _isTransfer,
                labelOverride: _isTransfer ? loc.transferAmount : null,
              ),
              validator: (val) {
                final amount = parseFormattedAmount(val ?? '');
                if (amount <= 0 || amount > AppConstants.maxAmount) {
                  return loc.pleaseEnterValidAmount;
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              child: DatePickerField(
                selectedDate: _date,
                onDateSelected: (date) => setState(() => _date = date),
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            AccountPicker(
              label: _isTransfer ? loc.fromAccount : loc.account,
              selectedAccountId: _accountId,
              excludeIds: _isTransfer && _toAccountId != null ? [_toAccountId!] : const [],
              validator: (val) => val == null ? loc.selectAnAccount : null,
              onAccountSelected: (id) => setState(() {
                _accountId = id;
                _error = null;
                _templateFeedback = null;
              }),
            ),
            if (_isTransfer) ...[
              const SizedBox(height: AppConstants.spacingLg),
              AccountPicker(
                label: loc.toAccount,
                selectedAccountId: _toAccountId,
                excludeIds: _accountId != null ? [_accountId!] : const [],
                validator: (val) => val == null ? loc.selectAnAccount : null,
                onAccountSelected: (id) => setState(() {
                  _toAccountId = id;
                  _error = null;
                  _templateFeedback = null;
                }),
              ),
            ] else ...[
              const SizedBox(height: AppConstants.spacingLg),
              MerchantField(
                initialValue: _merchant,
                onChanged: (val) => _merchant = val,
                onAccountDefault: (accountId) => setState(() => _accountId = accountId),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              CategoryPicker(
                isIncome: _isIncome,
                selectedCategoryId: _categoryId,
                validator: (val) => val == null ? loc.pleaseSelectCategory : null,
                onCategorySelected: (id) => setState(() {
                  _categoryId = id;
                  _error = null;
                  _templateFeedback = null;
                }),
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // Note and recurrence — both used to live behind "More
              // options" on the full screen. Neither applies to a
              // transfer, which is why they sit in this branch.
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
                    const SizedBox(height: AppConstants.spacingSm),
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
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppConstants.spacingSm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                ),
              ),
            ] else if (_templateFeedback != null) ...[
              const SizedBox(height: AppConstants.spacingSm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                child: Text(
                  _templateFeedback!,
                  style: TextStyle(
                    color: theme.brightness == Brightness.dark ? AppColors.darkIncome : AppColors.lightIncome,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal row of saved one-tap templates ("favorites") — tap to
/// instantly post today's transaction from it, long-press to delete.
/// Hidden entirely once there are no templates, rather than showing an
/// empty-state hint in an already-compact sheet.
class _TemplateChipsRow extends StatelessWidget {
  final ValueChanged<TemplateModel> onSelected;
  final void Function(BuildContext, TemplateModel) onDelete;

  const _TemplateChipsRow({required this.onSelected, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = context.watch<TemplateProvider>().templates;
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();

    if (templates.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
        itemCount: templates.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppConstants.spacingSm),
        itemBuilder: (context, index) {
          final template = templates[index];
          final category = categories.getCategoryById(template.categoryId);
          return GestureDetector(
            onTap: () => onSelected(template),
            onLongPress: () => onDelete(context, template),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: category?.colorValue ?? theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(template.name, style: theme.textTheme.labelMedium),
                  const SizedBox(width: 6),
                  Text(
                    NumberUtils.formatCompact(template.amount, symbol: settings.currencySymbol),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Three-way Expense/Income/Transfer segmented control — the same visual
/// language as [TypeToggle] but with a third segment, kept private to this
/// sheet since nothing else needs a transfer option inline.
class _EntryTypeSegments extends StatelessWidget {
  final _EntryType entryType;
  final ValueChanged<_EntryType> onChanged;
  final String expenseLabel;
  final String incomeLabel;
  final String transferLabel;

  const _EntryTypeSegments({
    required this.entryType,
    required this.onChanged,
    required this.expenseLabel,
    required this.incomeLabel,
    required this.transferLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A 3px inset between the track and the selected pill — without it the
    // track's own fill is entirely hidden behind the selected segment, so
    // the control doesn't read as "three options in a group" at rest.
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          _segment(context, expenseLabel, _EntryType.expense),
          _segment(context, incomeLabel, _EntryType.income),
          _segment(context, transferLabel, _EntryType.transfer),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, _EntryType type) {
    final theme = Theme.of(context);
    final isSelected = entryType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
