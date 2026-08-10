import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/debt_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/utils/debt_payoff.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/keypad_amount_field.dart';

/// Simple single-debt payoff estimate: "at $X/month, this debt clears in
/// N months." A flat month-by-month simulation (see monthsToPayOff), not a
/// multi-debt snowball/avalanche optimizer — that's a materially bigger
/// feature (ranking and sequencing every active debt) that the plan marked
/// optional; this covers the common "how long until I'm debt-free on this
/// one" question a payoff calculator is usually reached for.
class PayoffCalculatorDialog extends StatefulWidget {
  final DebtModel debt;
  final double outstanding;

  const PayoffCalculatorDialog({super.key, required this.debt, required this.outstanding});

  static void show(BuildContext context, DebtModel debt, double outstanding) {
    showDialog(
      context: context,
      builder: (_) => PayoffCalculatorDialog(debt: debt, outstanding: outstanding),
    );
  }

  @override
  State<PayoffCalculatorDialog> createState() => _PayoffCalculatorDialogState();
}

class _PayoffCalculatorDialogState extends State<PayoffCalculatorDialog> {
  final _paymentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The estimate below the field is recomputed on every change to the
    // amount. It used to hang off the field's `onChanged`, which the keypad
    // never fires — it writes `controller.text` directly — so listen to the
    // controller instead.
    _paymentController.addListener(_onPaymentChanged);
  }

  void _onPaymentChanged() => setState(() {});

  @override
  void dispose() {
    _paymentController.removeListener(_onPaymentChanged);
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final payment = parseFormattedAmount(_paymentController.text);
    final months = payment > 0
        ? monthsToPayOff(
            outstanding: widget.outstanding,
            monthlyPayment: payment,
            monthlyInterestRate: widget.debt.interestRate ?? 0,
          )
        : null;

    return AlertDialog(
      title: Text(loc.payoffCalculator),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.payoffOutstandingLabel(
              NumberUtils.formatCurrency(widget.outstanding, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          KeypadAmountField(
            controller: _paymentController,
            labelText: loc.monthlyPayment,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          if (payment > 0)
            Text(
              months == null ? loc.payoffNeverAtThisRate : loc.payoffMonthsEstimate(months),
              style: Theme.of(context).textTheme.titleMedium,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.cancel),
        ),
      ],
    );
  }
}
