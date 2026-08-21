import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/category_model.dart';
import '../../../providers/category_provider.dart';
import '../../../widgets/picker_sheet.dart';
import '../../../l10n/app_localizations.dart';

/// Narrows a group budget down to the one category a new expense should be
/// filed under, before handing off to the add sheet.
///
/// Deliberately not [CategoryPicker]: that offers every expense category and
/// a "create new" row, which would let the user file the entry outside the
/// budget they started from. This lists only the budget's own categories.
class BudgetCategoryPickerSheet extends StatelessWidget {
  final List<String> categoryIds;

  const BudgetCategoryPickerSheet({super.key, required this.categoryIds});

  /// Resolves to the chosen category id, or null if the sheet was dismissed.
  static Future<String?> show(
    BuildContext context, {
    required List<String> categoryIds,
  }) {
    return PickerSheet.show<String>(
      context,
      builder: (_) => BudgetCategoryPickerSheet(categoryIds: categoryIds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final provider = context.watch<CategoryProvider>();
    final categories = categoryIds
        .map(provider.getCategoryById)
        .whereType<CategoryModel>()
        .toList();

    return PickerSheet(
      title: loc.selectACategory,
      children: [
        for (final category in categories)
          ListTile(
            leading: Icon(category.iconData, color: category.colorValue),
            title: Text(category.name),
            onTap: () => Navigator.of(context).pop(category.id),
          ),
      ],
    );
  }
}
