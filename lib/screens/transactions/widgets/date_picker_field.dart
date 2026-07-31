import 'package:flutter/material.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';

/// Form field for selecting a date, styled like an input field.
class DatePickerField extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const DatePickerField({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      onDateSelected(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.date,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: AppConstants.spacingSm),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
              vertical: AppConstants.spacingMd,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Text(
                  AppDateUtils.formatFull(selectedDate),
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
