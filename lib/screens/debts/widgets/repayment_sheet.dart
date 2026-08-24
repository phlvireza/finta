import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../models/debt_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/database/seed_data.dart';
import '../../../core/utils/squi_moments.dart';
import '../../../core/services/squi_milestone_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/keypad_amount_field.dart';
import '../../../widgets/squi/squi_moment_sheet.dart';
import '../../transactions/widgets/account_picker.dart';
import '../../transactions/widgets/category_picker.dart';
import '../../transactions/widgets/date_picker_field.dart';

/// Bottom sheet to log a repayment against a debt. For a debt you owe
/// ('borrowed'), a repayment is money leaving one of your accounts — an
/// expense. For a debt owed to you ('lent'), a repayment is money coming
/// back — income. Either way it's an ordinary transaction tagged with this
/// debt's id, so it shows up in Records/analytics/CSV export for free.
///
/// The category defaults to "Debt Payments"/"Debt Repayments" but is
/// editable, and so is the date. Repaid totals are derived from `debtId`,
/// never from the category (`DebtRepository.getAllRepaid`), so neither field
/// can put a debt's balance out of step with its repayments. Making it
/// editable matters most once there is more than one debt, where every
/// payment otherwise collapses into a single category in analytics.
class RepaymentSheet extends StatefulWidget {
  final DebtModel debt;

  const RepaymentSheet({super.key, required this.debt});

  static Future<void> show(BuildContext context, DebtModel debt) async {
    final result = await showModalBottomSheet<SquiSaveResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RepaymentSheet(debt: debt),
    );
    if (result?.moment != null && context.mounted) {
      await SquiMomentSheet.show(
        context,
        result!.moment!,
        name: result.subjectName,
      );
    }
  }

  @override
  State<RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends State<RepaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _accountId;
  late String _categoryId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  /// A repayment on a debt you owe is spending; a repayment on money you lent
  /// out is income coming back. The picker has to be filtered to the matching
  /// side or it would offer categories the transaction type can never use.
  bool get _isIncome => !widget.debt.isBorrowed;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.debt.isBorrowed
        ? SeedData.debtPaymentsCategoryId
        : SeedData.debtRepaymentsCategoryId;
    // The debt categories are seeded as ordinary categories, so a user can
    // archive them. CategoryPicker renders blank for an id it can't resolve,
    // which would look like an unset field with no explanation — fall back to
    // any category of the right type instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<CategoryProvider>();
      final categories = _isIncome
          ? provider.incomeCategories
          : provider.expenseCategories;
      if (categories.any((c) => c.id == _categoryId) || categories.isEmpty) {
        return;
      }
      setState(() => _categoryId = categories.first.id);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _accountId == null) {
      setState(() {});
      return;
    }
    setState(() => _isSaving = true);
    final loc = AppLocalizations.of(context)!;
    // A repayment is an ordinary transaction, so everything a transaction
    // moves has to be reloaded here too — captured before the first await.
    // Reloading only the debt used to leave net worth and the account
    // carousel stale until the app was restarted, which is most visible on a
    // 'lent' debt, where the repayment is income that should *raise* the
    // account's balance on screen.
    final txProvider = context.read<TransactionProvider>();
    final debtProvider = context.read<DebtProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final accountProvider = context.read<AccountProvider>();
    final analytics = context.read<AnalyticsProvider>();
    final settings = context.read<SettingsProvider>();
    try {
      final wasSettled = debtProvider.isSettled(widget.debt);
      final wasLedgerEmpty = !await txProvider.hasAnyNonTransferTransaction();
      await txProvider.addTransaction(
        type: widget.debt.isBorrowed ? 'expense' : 'income',
        amount: parseFormattedAmount(_amountController.text),
        categoryId: _categoryId,
        accountId: _accountId!,
        date: _date,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        debtId: widget.debt.id,
      );
      await txProvider.loadTransactions(payday: settings.payday);
      await budgetProvider.loadBudgets(payday: settings.payday);
      await accountProvider.loadAccounts();
      await analytics.loadForCurrentPeriod(settings.payday);
      await debtProvider.loadDebts();
      final isSettled = debtProvider.isSettled(widget.debt);
      final eligible = <SquiMoment>{
        if (wasLedgerEmpty) SquiMoment.firstTransaction,
        if (!wasSettled && isSettled) SquiMoment.debtSettled,
      };
      final moment = await SquiMilestoneService.instance.claim(
        eligible: eligible,
        debtId: widget.debt.id,
      );
      if (mounted) {
        Navigator.of(context).pop(
          SquiSaveResult(
            saved: true,
            moment: moment,
            subjectName: widget.debt.name,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.errorFailedToSave)));
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
        bottom:
            MediaQuery.of(context).viewInsets.bottom + AppConstants.spacingLg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.logRepayment(widget.debt.name),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppConstants.spacingXxl),
              KeypadAmountField(
                controller: _amountController,
                labelText: loc.amount,
                keypadLabel: loc.logRepayment(widget.debt.name),
                // Money coming back on a debt you lent out is income, so the
                // keypad should read in the income colour.
                isIncome: _isIncome,
                validator: requiredAmountValidator(loc),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              AccountPicker(
                label: widget.debt.isBorrowed ? loc.fromAccount : loc.toAccount,
                selectedAccountId: _accountId,
                onAccountSelected: (id) => setState(() => _accountId = id),
                validator: (_) =>
                    _accountId == null ? loc.selectAnAccount : null,
              ),
              const SizedBox(height: AppConstants.spacingLg),
              CategoryPicker(
                isIncome: _isIncome,
                selectedCategoryId: _categoryId,
                onCategorySelected: (id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              // Padded to line up with AccountPicker and CategoryPicker,
              // which both inset themselves; DatePickerField doesn't.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg,
                ),
                child: DatePickerField(
                  selectedDate: _date,
                  onDateSelected: (date) => setState(() => _date = date),
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
