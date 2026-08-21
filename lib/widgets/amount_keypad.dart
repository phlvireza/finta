import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/formatters/currency_formatter.dart';
import '../core/utils/expression_evaluator.dart';
import '../core/utils/keypad_buffer.dart';
import '../l10n/app_localizations.dart';

/// Full-screen numeric keypad that replaces the OS keyboard for amount
/// entry — a near-full-height modal sheet rather than a docked strip, so it
/// has room to show the amount being typed at a readable size and gives
/// the transition somewhere to go (a fade combined with the sheet's own
/// slide-up).
///
/// Two reasons it exists rather than a `numberWithOptions` keyboard: the
/// platform keypad's keys are small and its layout differs per vendor, and
/// IDR amounts run to six or seven digits, where a `000` key removes most
/// of the typing. Arithmetic comes along for free — it replaces the old
/// calculator bottom sheet, which required a detour to reach.
///
/// The keypad drives [controller] directly, so whatever field opened it
/// shows the same value once the sheet closes. What it writes there is
/// *formatted for reading* (`12,000+3,500`); the raw expression lives here
/// in [_expression], because [CurrencyInputFormatter] is a strict numeric
/// mask with no notion of operators and commas would break the evaluator.
class AmountKeypad extends StatefulWidget {
  final TextEditingController controller;
  final bool isIncome;
  final String? labelOverride;
  final VoidCallback onDone;

  const AmountKeypad({
    super.key,
    required this.controller,
    required this.isIncome,
    required this.onDone,
    this.labelOverride,
  });

  /// Opens the keypad as a near-full-height modal sheet. Tapping the scrim,
  /// swiping down, or the system back gesture all dismiss it the same as
  /// Done — [_AmountKeypadState.dispose] finalizes whatever was typed
  /// either way, so there's no path that discards it.
  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    required bool isIncome,
    String? labelOverride,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.92,
        child: AmountKeypad(
          controller: controller,
          isIncome: isIncome,
          labelOverride: labelOverride,
          onDone: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

  @override
  State<AmountKeypad> createState() => _AmountKeypadState();
}

class _AmountKeypadState extends State<AmountKeypad> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  // Captured once in initState rather than read via context in dispose —
  // dispose() runs on the way out of the tree, and _finalizeOnClose() (the
  // one thing that needs this on a swipe/scrim dismissal) runs there.
  // Reading through `context.read` is documented as safe even in dispose,
  // but this avoids relying on that and matches how the same concern was
  // handled for the recap screen's AnalyticsProvider.
  late final bool _useDecimals;

  String _expression = '';
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _useDecimals = context.read<SettingsProvider>().currencyUseDecimals;
    // Adopt whatever is already in the field (an amount being edited)
    // instead of starting blank and silently discarding it on first key.
    _expression = widget.controller.text.replaceAll(',', '');
    // The sheet's own transition already slides it up; this fade is the
    // one piece of that entrance this widget owns itself, so it plays
    // however the sheet was opened — scrim tap, drag, or the trigger tap.
    _fadeController = AnimationController(
      vsync: this,
      duration: AppConstants.animNormal,
    )..forward();
  }

  bool get _hasOperator => _expression.contains(RegExp(r'[+\-*/]'));

  void _press(String key) {
    setState(() {
      _expression = applyKeypadKey(
        _expression,
        key,
        allowDecimals: _useDecimals,
        maxDigits: AppConstants.maxAmountDigits,
      );
      _invalid = false;
      _syncController();
    });
  }

  /// Mirrors the raw expression into the shared controller. Writing
  /// `controller.text` bypasses the field's input formatters, which is what
  /// lets an operator appear there at all while the user is mid-expression.
  void _syncController() {
    final text = formatExpressionWithSeparators(_expression);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Collapses the expression to its result. Returns false when it doesn't
  /// parse, so [_done] can refuse to close over a broken value.
  bool _evaluate() {
    if (!_hasOperator) {
      // "5." is a half-typed number, not an expression — trim it rather
      // than leaving a dangling separator in the saved amount.
      if (_expression.endsWith('.')) {
        setState(() {
          _expression = _expression.substring(0, _expression.length - 1);
          _syncController();
        });
      }
      return true;
    }
    if (!isKeypadExpressionComplete(_expression)) {
      setState(() => _invalid = true);
      return false;
    }

    final result = evaluateExpression(_expression);
    if (result == null || result.isNaN || result.isInfinite) {
      setState(() => _invalid = true);
      return false;
    }

    setState(() {
      // A negative subtotal is not an amount. Keep the expression on screen
      // so the user can fix it rather than silently clamping to zero.
      if (result < 0) {
        _invalid = true;
        return;
      }
      _expression = formatAmount(result, useDecimals: _useDecimals).replaceAll(',', '');
      _invalid = false;
      _syncController();
    });
    return !_invalid;
  }

  void _done() {
    // The controller must never still hold an operator once the keypad
    // closes — `parseFormattedAmount` would read "500+500" as 0.
    if (!_evaluate()) return;
    widget.onDone();
  }

  /// Best-effort finalize for every dismissal path that isn't Done — swipe
  /// down, tapping the scrim, the system back gesture. Every keystroke is
  /// mirrored straight into the shared controller as it's typed, so without
  /// this an abandoned "500+" or an un-equals'd "500+500" would be read
  /// back as 0 by `parseFormattedAmount` instead of 500 or 1000.
  ///
  /// Safe to run unconditionally, including after a normal Done: trimming
  /// or evaluating an already-clean number is a no-op.
  void _finalizeOnClose() {
    var expr = _expression;
    while (expr.isNotEmpty &&
        (expr.endsWith('.') || '+-*/'.contains(expr[expr.length - 1]))) {
      expr = expr.substring(0, expr.length - 1);
    }
    if (expr.isEmpty) {
      widget.controller.value = const TextEditingValue(text: '');
      return;
    }

    if (RegExp(r'[+\-*/]').hasMatch(expr)) {
      final result = evaluateExpression(expr);
      if (result != null && result >= 0 && !result.isNaN && !result.isInfinite) {
        expr = formatAmount(result, useDecimals: _useDecimals).replaceAll(',', '');
      } else {
        // Division by zero or similar is the only way evaluation still
        // fails here — `applyKeypadKey` never lets two operators or two
        // decimal points land next to each other. Fall back to whatever
        // complete leading number can be salvaged rather than losing the
        // entry outright.
        expr = RegExp(r'^-?\d+(\.\d+)?').stringMatch(expr) ?? '';
      }
    }

    final text = formatExpressionWithSeparators(expr);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _finalizeOnClose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;

    final color = widget.isIncome
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
      child: Material(
        color: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXl)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.labelOverride ?? (widget.isIncome ? loc.incomeAmount : loc.expenseAmount),
                        style: theme.textTheme.labelMedium?.copyWith(color: color),
                      ),
                      const SizedBox(height: AppConstants.spacingSm),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller,
                        builder: (context, value, _) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  settings.currencySymbol,
                                  style: theme.textTheme.headlineMedium?.copyWith(color: color),
                                ),
                                const SizedBox(width: AppConstants.spacingXs),
                                Text(
                                  value.text.isEmpty ? '0' : value.text,
                                  style: AppTypography.amountStyle(color: color, fontSize: 40),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (_invalid) ...[
                        const SizedBox(height: AppConstants.spacingSm),
                        Text(
                          loc.invalidExpression,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingLg,
                  0,
                  AppConstants.spacingLg,
                  AppConstants.spacingLg,
                ),
                child: Column(
                  children: [
                    _row(['7', '8', '9', '/']),
                    _row(['4', '5', '6', '*']),
                    _row(['1', '2', '3', '-']),
                    _row(['000', '0', '.', '+']),
                    const SizedBox(height: AppConstants.spacingSm),
                    Row(
                      children: [
                        Expanded(
                          child: _KeypadButton(
                            onPressed: () => _press('backspace'),
                            child: const Icon(Icons.backspace_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Expanded(
                          child: _KeypadButton(
                            onPressed: () => _press('clear'),
                            child: const Text('C', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Expanded(
                          child: _KeypadButton(
                            onPressed: _evaluate,
                            isOperator: true,
                            child: const Text('=', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Expanded(
                          flex: 2,
                          child: _KeypadButton(
                            onPressed: _done,
                            isPrimary: true,
                            child: Text(loc.done, style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Row(
        children: [
          for (final key in keys) ...[
            Expanded(child: _keyButton(key)),
            if (key != keys.last) const SizedBox(width: AppConstants.spacingXs),
          ],
        ],
      ),
    );
  }

  Widget _keyButton(String key) {
    const glyphs = {'/': '÷', '*': '×', '-': '−'};
    final isOperator = glyphs.containsKey(key) || key == '+';
    // The dot is dead weight on IDR/JPY — dim it rather than removing it,
    // so the grid doesn't reflow when the user changes currency.
    final isDisabled = key == '.' && !_useDecimals;

    return _KeypadButton(
      onPressed: isDisabled ? null : () => _press(key),
      isOperator: isOperator,
      child: Text(
        glyphs[key] ?? key,
        style: TextStyle(fontSize: key.length > 1 ? 18 : 22),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isOperator;
  final bool isPrimary;

  const _KeypadButton({
    required this.onPressed,
    required this.child,
    this.isOperator = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 18)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
      ),
      backgroundColor: WidgetStatePropertyAll(
        isPrimary ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
      ),
      foregroundColor: WidgetStatePropertyAll(
        isPrimary
            ? theme.colorScheme.onPrimary
            : (isOperator ? theme.colorScheme.primary : theme.colorScheme.onSurface),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );

    return TextButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}
