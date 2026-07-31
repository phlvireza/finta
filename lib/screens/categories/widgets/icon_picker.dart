import 'package:flutter/material.dart';
import '../../../models/category_model.dart';
import '../../../core/constants/app_constants.dart';

/// Dialog for selecting an icon from the predefined list.
class IconPickerDialog extends StatelessWidget {
  const IconPickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icons = CategoryModel.availableIcons.entries.toList();

    return AlertDialog(
      title: const Text('Select Icon'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 60,
            mainAxisSpacing: AppConstants.spacingMd,
            crossAxisSpacing: AppConstants.spacingMd,
          ),
          itemCount: icons.length,
          itemBuilder: (context, index) {
            final entry = icons[index];
            return InkWell(
              onTap: () => Navigator.of(context).pop(entry.key),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(entry.value, color: theme.colorScheme.onSurface),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
