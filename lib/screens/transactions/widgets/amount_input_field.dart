import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';

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

    final textStyle = AppTypography.amountStyle(
      color: color,
      fontSize: 48,
    );

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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    settings.currencySymbol,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                    ),
                  ),
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
                ],
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
