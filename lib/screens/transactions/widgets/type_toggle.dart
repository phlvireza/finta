import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Pill-shaped Expense/Income segmented toggle, shared by the full
/// transaction form and the quick-add sheet.
class TypeToggle extends StatelessWidget {
  final bool isIncome;
  final ValueChanged<bool> onChanged;
  final String expenseLabel;
  final String incomeLabel;

  const TypeToggle({
    super.key,
    required this.isIncome,
    required this.onChanged,
    required this.expenseLabel,
    required this.incomeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeToggleButton(
              label: expenseLabel,
              isSelected: !isIncome,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _TypeToggleButton(
              label: incomeLabel,
              isSelected: isIncome,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.textTheme.bodyMedium?.color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
