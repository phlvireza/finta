import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../models/goal_model.dart';
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

/// Bottom sheet to log a contribution toward a goal. A contribution is
/// just an ordinary expense transaction — tagged with this goal's id — so it
/// shows up in Records, analytics, and CSV export like any other transaction.
///
/// The category defaults to "Savings & Goals" but is editable, and so is the
/// date. Progress is derived from `goalId`, never from the category
/// (`GoalRepository.getAllProgress`), so neither field can put a goal's total
/// out of step with the transactions behind it.
class ContributeToGoalSheet extends StatefulWidget {
  final GoalModel goal;

  /// Amount the sheet opens with already filled in, for callers that
  /// already know the figure — sweeping an ended budget's leftover into
  /// this goal. Still editable; null leaves the field empty as usual.
  final double? initialAmount;

  const ContributeToGoalSheet({
    super.key,
    required this.goal,
    this.initialAmount,
  });

  /// Resolves to true when a contribution was actually saved, false when
  /// the sheet was dismissed.
  static Future<bool> show(
    BuildContext context,
    GoalModel goal, {
    double? initialAmount,
  }) async {
    final result = await showModalBottomSheet<SquiSaveResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          ContributeToGoalSheet(goal: goal, initialAmount: initialAmount),
    );
    if (result?.moment != null && context.mounted) {
      await SquiMomentSheet.show(
        context,
        result!.moment!,
        name: result.subjectName,
      );
    }
    return result?.saved ?? false;
  }

  @override
  State<ContributeToGoalSheet> createState() => _ContributeToGoalSheetState();
}

class _ContributeToGoalSheetState extends State<ContributeToGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _accountId;
  String _categoryId = SeedData.savingsGoalsCategoryId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      // Through the formatter, not toString: KeypadAmountField shows a
      // masked amount and a raw "200000.0" would read as typed garbage.
      _amountController.text = formatAmount(
        widget.initialAmount!,
        useDecimals: context.read<SettingsProvider>().currencyUseDecimals,
      );
    }
    // "Savings & Goals" is seeded as an ordinary category, so a user can
    // archive it. CategoryPicker only resolves non-archived categories and
    // renders blank when the id doesn't match one, which would leave the
    // field looking unset with no way to tell why — fall back to any expense
    // category instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final categories = context.read<CategoryProvider>().expenseCategories;
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
    // A contribution is an ordinary expense, so everything an expense moves
    // has to be reloaded here too — captured before the first await.
    // Reloading only the goal used to leave net worth, the account carousel
    // and any budget covering "Savings & Goals" showing pre-contribution
    // numbers until the app was restarted.
    final txProvider = context.read<TransactionProvider>();
    final goalProvider = context.read<GoalProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final accountProvider = context.read<AccountProvider>();
    final analytics = context.read<AnalyticsProvider>();
    final settings = context.read<SettingsProvider>();
    try {
      final beforeProgress = goalProvider.progressOf(widget.goal.id);
      final wasLedgerEmpty = !await txProvider.hasAnyNonTransferTransaction();
      await txProvider.addTransaction(
        type: 'expense',
        amount: parseFormattedAmount(_amountController.text),
        categoryId: _categoryId,
        accountId: _accountId!,
        date: _date,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        goalId: widget.goal.id,
      );
      await txProvider.loadTransactions(payday: settings.payday);
      await budgetProvider.loadBudgets(payday: settings.payday);
      await accountProvider.loadAccounts();
      await analytics.loadForCurrentPeriod(settings.payday);
      await goalProvider.loadGoals();
      final afterProgress = goalProvider.progressOf(widget.goal.id);
      final eligible = <SquiMoment>{
        if (wasLedgerEmpty) SquiMoment.firstTransaction,
        if (beforeProgress < widget.goal.targetAmount &&
            afterProgress >= widget.goal.targetAmount)
          SquiMoment.goalReached,
      };
      final moment = await SquiMilestoneService.instance.claim(
        eligible: eligible,
        goalId: widget.goal.id,
      );
      if (mounted) {
        Navigator.of(context).pop(
          SquiSaveResult(
            saved: true,
            moment: moment,
            subjectName: widget.goal.name,
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
                loc.contributeToGoal(widget.goal.name),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppConstants.spacingXxl),
              KeypadAmountField(
                controller: _amountController,
                labelText: loc.amount,
                keypadLabel: loc.contributeToGoal(widget.goal.name),
                validator: requiredAmountValidator(loc),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              AccountPicker(
                label: loc.fromAccount,
                selectedAccountId: _accountId,
                onAccountSelected: (id) => setState(() => _accountId = id),
                validator: (_) =>
                    _accountId == null ? loc.selectAnAccount : null,
              ),
              const SizedBox(height: AppConstants.spacingLg),
              CategoryPicker(
                isIncome: false,
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
