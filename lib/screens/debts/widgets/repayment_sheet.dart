import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../models/debt_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/database/seed_data.dart';
import '../../../l10n/app_localizations.dart';
import '../../transactions/widgets/account_picker.dart';

/// Bottom sheet to log a repayment against a debt. For a debt you owe
/// ('borrowed'), a repayment is money leaving one of your accounts — an
/// expense. For a debt owed to you ('lent'), a repayment is money coming
/// back — income. Either way it's an ordinary transaction tagged with this
/// debt's id, so it shows up in Records/analytics/CSV export for free.
class RepaymentSheet extends StatefulWidget {
  final DebtModel debt;

  const RepaymentSheet({super.key, required this.debt});

  static void show(BuildContext context, DebtModel debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => RepaymentSheet(debt: debt),
    );
  }

  @override
  State<RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends State<RepaymentSheet> {
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
            type: widget.debt.isBorrowed ? 'expense' : 'income',
            amount: parseFormattedAmount(_amountController.text),
            categoryId: widget.debt.isBorrowed
                ? SeedData.debtPaymentsCategoryId
                : SeedData.debtRepaymentsCategoryId,
            accountId: _accountId!,
            date: DateTime.now(),
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            debtId: widget.debt.id,
          );
      await context.read<DebtProvider>().loadDebts();
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
                loc.logRepayment(widget.debt.name),
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
                label: widget.debt.isBorrowed ? loc.fromAccount : loc.toAccount,
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
