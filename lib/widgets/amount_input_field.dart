import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_typography.dart';
import '../core/formatters/currency_formatter.dart';
import '../core/utils/amount_field_fit.dart';
import '../l10n/app_localizations.dart';

/// Rough painted width of the currency symbol. Measured with a
/// [TextPainter] rather than estimated: symbols range from a one-character
/// `$` to a two-character `Rp`, and over-reserving here would shrink the
/// number more than necessary.
double _symbolWidth(String symbol, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: symbol, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// Amount input field with custom formatting and large typography.
class AmountInputField extends StatefulWidget {
  final TextEditingController controller;
  final bool isIncome;
  final FormFieldValidator<String>? validator;
  final String? labelOverride;
  final bool autofocus;

  /// Tapping the field opens the full-screen keypad sheet instead of
  /// focusing in place — the field is read-only and the caller owns showing
  /// `AmountKeypad` (via `AmountKeypad.show`).
  ///
  /// Required, so every amount in the app — transaction, quick add, budget —
  /// is typed on the same keypad, with the same `000` key, the same
  /// arithmetic and the same formatting. Budgets used to fall back to the
  /// OS keyboard plus a calculator-sheet detour, which is what made a budget
  /// amount feel like a different control from an expense amount.
  final VoidCallback onKeypadRequested;

  const AmountInputField({
    super.key,
    required this.controller,
    required this.isIncome,
    required this.onKeypadRequested,
    this.validator,
    this.labelOverride,
    this.autofocus = false,
  });

  @override
  State<AmountInputField> createState() => _AmountInputFieldState();
}

class _AmountInputFieldState extends State<AmountInputField> {
  /// Held so controller writes that did not come from typing — the
  /// full-screen [AmountKeypad] sets `controller.text` outright, which
  /// fires no `onChanged` — still reach the form. Without this the field
  /// would show the keypad's number while the [FormField] validated a
  /// stale one.
  FormFieldState<String>? _fieldState;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFieldState);
  }

  @override
  void didUpdateWidget(AmountInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFieldState);
      widget.controller.addListener(_syncFieldState);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFieldState);
    super.dispose();
  }

  void _syncFieldState() {
    final state = _fieldState;
    if (state == null || state.value == widget.controller.text) return;
    state.didChange(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final controller = widget.controller;
    final isIncome = widget.isIncome;

    final color = isIncome
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

    return FormField<String>(
      validator: widget.validator,
      initialValue: controller.text,
      builder: (FormFieldState<String> state) {
        _fieldState = state;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingXxl,
          ),
          child: Column(
            children: [
              Text(
                widget.labelOverride ??
                (isIncome
                  ? AppLocalizations.of(context)!.incomeAmount 
                  : AppLocalizations.of(context)!.expenseAmount),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              // The number shrinks to fit rather than scrolling inside its
              // own field: at a fixed 48px only ~7 characters fit next to
              // the currency symbol, so anything longer used to slide its
              // leading digits out of sight. LayoutBuilder supplies the real
              // width; ValueListenableBuilder re-measures on every keystroke.
              LayoutBuilder(
                builder: (context, constraints) {
                  final symbolStyle = theme.textTheme.headlineMedium?.copyWith(
                    color: color,
                  );
                  // Everything the number does not get: the symbol and the
                  // gap on either side of it.
                  final reserved = _symbolWidth(settings.currencySymbol, symbolStyle) +
                      AppConstants.spacingXs * 2;

                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final textStyle = AppTypography.amountStyle(
                        color: color,
                        fontSize: fitAmountFontSize(
                          characterCount: value.text.length,
                          maxWidth: constraints.maxWidth - reserved,
                        ),
                      );

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(settings.currencySymbol, style: symbolStyle),
                          const SizedBox(width: AppConstants.spacingXs),
                          Flexible(
                            child: IntrinsicWidth(
                              child: TextField(
                                controller: controller,
                                autofocus: widget.autofocus,
                                // readOnly keeps the OS keyboard shut; the
                                // tap opens the keypad sheet via onTap
                                // instead of focusing in place.
                                readOnly: true,
                                showCursor: false,
                                enableInteractiveSelection: false,
                                onTap: widget.onKeypadRequested,
                                onChanged: (val) => state.didChange(val),
                                style: textStyle,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  fillColor: Colors.transparent,
                                  hintText: '0',
                                  hintStyle: textStyle.copyWith(
                                    color: color.withValues(alpha: 0.3),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                inputFormatters: [
                                  CurrencyInputFormatter(
                                    allowDecimals: settings.currencyUseDecimals,
                                    maxDigits: AppConstants.maxAmountDigits,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingXs),
                        ],
                      );
                    },
                  );
                },
              ),
              if (state.hasError) ...[
                const SizedBox(height: AppConstants.spacingSm),
                Text(
                  state.errorText!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
