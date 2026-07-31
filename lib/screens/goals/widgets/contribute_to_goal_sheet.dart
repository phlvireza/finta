import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/goal_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../models/goal_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/database/seed_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../transactions/widgets/account_picker.dart';

/// Bottom sheet to log a contribution toward a goal. A contribution is
/// just an ordinary expense transaction — filed under the "Savings & Goals"
/// category and tagged with this goal's id — so it shows up in Records,
/// analytics, and CSV export like any other transaction.
class ContributeToGoalSheet extends StatefulWidget {
  final GoalModel goal;

  const ContributeToGoalSheet({super.key, required this.goal});

  static void show(BuildContext context, GoalModel goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ContributeToGoalSheet(goal: goal),
    );
  }

  @override
  State<ContributeToGoalSheet> createState() => _ContributeToGoalSheetState();
}

class _ContributeToGoalSheetState extends State<ContributeToGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _accountId;
  bool _isSaving = false;

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
    try {
      await context.read<TransactionProvider>().addTransaction(
            type: 'expense',
            amount: parseFormattedAmount(_amountController.text),
            categoryId: SeedData.savingsGoalsCategoryId,
            accountId: _accountId!,
            date: DateTime.now(),
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            goalId: widget.goal.id,
          );
      await context.read<GoalProvider>().loadGoals();
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
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                autofocus: true,
                decoration: InputDecoration(
                  labelText: loc.amount,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) =>
                    parseFormattedAmount(val ?? '') <= 0 ? loc.pleaseEnterValidAmount : null,
              ),
              const SizedBox(height: AppConstants.spacingLg),
              AccountPicker(
                label: loc.fromAccount,
                selectedAccountId: _accountId,
                onAccountSelected: (id) => setState(() => _accountId = id),
                validator: (_) => _accountId == null ? loc.selectAnAccount : null,
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
