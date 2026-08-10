import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/formatters/currency_formatter.dart';
import '../l10n/app_localizations.dart';
import 'amount_keypad.dart';

/// Inline money field for the app's ordinary forms — goal target, debt
/// principal, opening balance, credit limit, a contribution, a repayment.
///
/// It looks exactly like the filled `TextFormField`s it sits next to, but it
/// never takes keystrokes: tapping it opens the same [AmountKeypad] the
/// transaction screen uses. Before this existed, those fields fell back to
/// the OS numeric keyboard, so entering a debt principal felt like a
/// different control from entering an expense — no `000` key, no `+ − × ÷`,
/// and (because every one of them passed a bare `CurrencyInputFormatter()`,
/// whose default is `allowDecimals: false`) no way to type cents on a
/// decimal currency at all.
///
/// [AmountInputField] remains the *hero* variant — the big centred number on
/// screens whose whole purpose is one amount. This is the compact sibling for
/// forms with several fields, where a hero would push everything else below
/// the fold.
class KeypadAmountField extends StatefulWidget {
  final TextEditingController controller;

  /// Label on the field itself. Also the keypad's heading unless
  /// [keypadLabel] overrides it.
  final String labelText;
  final String? keypadLabel;

  /// Tints the keypad's heading and running total. Purely cosmetic — these
  /// fields are not all "expenses"; default to the expense colour because
  /// most of them (contributions, repayments, principals) are money going
  /// out or owed.
  final bool isIncome;

  /// Opens the keypad on the first frame. Used only by sheets whose sole
  /// purpose is entering one amount, which previously carried
  /// `autofocus: true` to pop the OS keyboard on open.
  final bool autoOpen;

  final FormFieldValidator<String>? validator;

  const KeypadAmountField({
    super.key,
    required this.controller,
    required this.labelText,
    this.keypadLabel,
    this.isIncome = false,
    this.autoOpen = false,
    this.validator,
  });

  @override
  State<KeypadAmountField> createState() => _KeypadAmountFieldState();
}

class _KeypadAmountFieldState extends State<KeypadAmountField> {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openKeypad();
      });
    }
  }

  void _openKeypad() {
    AmountKeypad.show(
      context,
      controller: widget.controller,
      isIncome: widget.isIncome,
      labelOverride: widget.keypadLabel ?? widget.labelText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    // A TextFormField rather than a raw TextField wrapped in a FormField:
    // TextFormField already listens to its controller and calls didChange,
    // so the keypad's direct `controller.text` write reaches validation on
    // its own. [AmountInputField] needs an explicit listener for this only
    // because it drives a bare TextField — don't copy that hack here.
    return TextFormField(
      controller: widget.controller,
      readOnly: true,
      showCursor: false,
      enableInteractiveSelection: false,
      onTap: _openKeypad,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixText: '${settings.currencySymbol} ',
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Validator for a money field that must hold a positive amount. Mirrors the
/// ceiling the transaction screen enforces, so a goal target and an expense
/// reject the same inputs.
FormFieldValidator<String> requiredAmountValidator(AppLocalizations loc) {
  return (value) {
    final amount = parseFormattedAmount(value ?? '');
    if (amount <= 0 || amount > AppConstants.maxAmount) {
      return loc.pleaseEnterValidAmount;
    }
    return null;
  };
}

/// Validator for a money field that may be left blank (opening balance,
/// credit limit) but must still be a sane number when filled in.
FormFieldValidator<String> optionalAmountValidator(AppLocalizations loc) {
  return (value) {
    if (value == null || value.trim().isEmpty) return null;
    final amount = parseFormattedAmount(value);
    if (amount > AppConstants.maxAmount) return loc.pleaseEnterValidAmount;
    return null;
  };
}
