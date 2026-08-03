import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../core/utils/amount_field_fit.dart';
import '../../../l10n/app_localizations.dart';
import 'calculator_sheet.dart';

/// Width an [IconButton] occupies at its default 48x48 tap target — the
/// slice of the row the number can never have.
const double _calculatorButtonWidth = 48;

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
class AmountInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isIncome;
  final FormFieldValidator<String>? validator;
  final String? labelOverride;
  final bool autofocus;

  const AmountInputField({
    super.key,
    required this.controller,
    required this.isIncome,
    this.validator,
    this.labelOverride,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;

    final color = isIncome
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

    return FormField<String>(
      validator: validator,
      initialValue: controller.text,
      builder: (FormFieldState<String> state) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingXxl,
          ),
          child: Column(
            children: [
              Text(
                labelOverride ??
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
              // the currency symbol and calculator button, so anything
              // longer used to slide its leading digits out of sight.
              // LayoutBuilder supplies the real width; ValueListenableBuilder
              // re-measures on every keystroke.
              LayoutBuilder(
                builder: (context, constraints) {
                  final symbolStyle = theme.textTheme.headlineMedium?.copyWith(
                    color: color,
                  );
                  // Everything the number does not get: the symbol, the
                  // calculator button, and the gap on either side of it.
                  final reserved = _symbolWidth(settings.currencySymbol, symbolStyle) +
                      _calculatorButtonWidth +
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
                                autofocus: autofocus,
                                onChanged: (val) => state.didChange(val),
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                          IconButton(
                            icon: Icon(Icons.calculate_outlined, color: color, size: 22),
                            tooltip: AppLocalizations.of(context)!.calculator,
                            onPressed: () async {
                              final result = await CalculatorSheet.show(context, initialValue: controller.text);
                              if (result == null) return;
                              final formatted = formatAmount(result, useDecimals: settings.currencyUseDecimals);
                              controller.text = formatted;
                              controller.selection = TextSelection.collapsed(offset: formatted.length);
                              state.didChange(formatted);
                            },
                          ),
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
