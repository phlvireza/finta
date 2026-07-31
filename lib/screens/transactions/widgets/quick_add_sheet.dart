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
import '../../../models/template_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/confirm_dialog.dart';
import '../add_transaction_screen.dart';
import 'amount_input_field.dart';
import 'category_picker.dart';
import 'account_picker.dart';
import 'merchant_field.dart';
import 'date_picker_field.dart';
import 'anomaly_confirm.dart';

enum _EntryType { expense, income, transfer }

/// Three-tap entry sheet opened from the FAB — amount, category, date,
/// save. Covers the common case fast; anything less common (recurring,
/// notes, editing) stays on the full [AddTransactionScreen]. Also handles
/// transfers, which never need a category — just two accounts.
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
  _EntryType _entryType = _EntryType.expense;
  DateTime _date = DateTime.now();
  String? _categoryId;
  String? _accountId;
  String? _toAccountId;
  String? _merchant;
  bool _isSaving = false;
  String? _error;

  bool get _isIncome => _entryType == _EntryType.income;
  bool get _isTransfer => _entryType == _EntryType.transfer;

  @override
  void initState() {
    super.initState();
    _prefillMostRecentCategory();
    _prefillMostRecentAccount();
  }

  void _prefillMostRecentCategory() {
    final recent = context.read<TransactionProvider>().recentTransactions;
    for (final tx in recent) {
      if (tx.isIncome == _isIncome && !tx.isTransfer) {
        _categoryId = tx.categoryId;
        break;
      }
    }
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
    super.dispose();
  }

  void _setEntryType(_EntryType type) {
    if (_entryType == type) return;
    setState(() {
      _entryType = type;
      _error = null;
      if (type != _EntryType.transfer) {
        _categoryId = null;
        _prefillMostRecentCategory();
      } else {
        _toAccountId = null;
      }
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
    if (_accountId == null) {
      setState(() => _error = loc.selectAnAccount);
      return;
    }
    if (_isTransfer) {
      if (_toAccountId == null) {
        setState(() => _error = loc.selectAnAccount);
        return;
      }
    } else if (_categoryId == null) {
      setState(() => _error = loc.pleaseSelectCategory);
      return;
    }

    // A statistical-outlier nudge, not a hard block — only for expenses,
    // which is the only case with a category to check history against.
    if (!_isTransfer && !_isIncome) {
      final check = await context.read<InsightsProvider>().checkAnomaly(_categoryId!, amount);
      if (check != null && check.isAnomaly) {
        if (!mounted) return;
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

      if (_isTransfer) {
        await txProvider.addTransfer(
          fromAccountId: _accountId!,
          toAccountId: _toAccountId!,
          amount: amount,
          date: _date,
        );
      } else {
        final trimmedMerchant = _merchant?.trim();
        await txProvider.addTransaction(
          type: _isIncome ? 'income' : 'expense',
          amount: amount,
          categoryId: _categoryId!,
          accountId: _accountId!,
          merchant: (trimmedMerchant == null || trimmedMerchant.isEmpty) ? null : trimmedMerchant,
          date: _date,
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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              AccountPicker(
                label: _isTransfer ? loc.fromAccount : loc.account,
                selectedAccountId: _accountId,
                excludeIds: _isTransfer && _toAccountId != null ? [_toAccountId!] : const [],
                onAccountSelected: (id) => setState(() {
                  _accountId = id;
                  _error = null;
                }),
              ),
              if (_isTransfer) ...[
                const SizedBox(height: AppConstants.spacingLg),
                AccountPicker(
                  label: loc.toAccount,
                  selectedAccountId: _toAccountId,
                  excludeIds: _accountId != null ? [_accountId!] : const [],
                  onAccountSelected: (id) => setState(() {
                    _toAccountId = id;
                    _error = null;
                  }),
                ),
              ] else ...[
                const SizedBox(height: AppConstants.spacingLg),
                MerchantField(
                  initialValue: _merchant,
                  onChanged: (val) => _merchant = val,
                  onMerchantDefaults: (categoryId, accountId) => setState(() {
                    _categoryId = categoryId;
                    _accountId = accountId;
                  }),
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
              ],
              const SizedBox(height: AppConstants.spacingLg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                child: Row(
                  children: [
                    if (!_isTransfer)
                      Expanded(
                        child: TextButton(
                          onPressed: _isSaving ? null : _openFullForm,
                          child: Text(loc.moreOptions),
                        ),
                      ),
                    if (!_isTransfer) const SizedBox(width: AppConstants.spacingMd),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: _isSaving
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _save,
                                style: ElevatedButton.styleFrom(backgroundColor: accentColor),
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
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spacingSm),
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
                border: Border.all(color: theme.colorScheme.outline),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category?.iconData ?? Icons.category, size: 16, color: category?.colorValue),
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
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
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
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
