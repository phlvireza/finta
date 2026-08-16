import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/seed_data.dart';
import '../../../core/utils/category_color.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/category_model.dart';
import '../../../providers/category_provider.dart';
import '../../../widgets/color_swatch_picker.dart';
import '../../../widgets/form_sheet.dart';
import '../../../widgets/tinted_icon.dart';

/// Colour-only editor for a category the app seeded.
///
/// A default category deliberately does not open the full `CategoryForm`.
/// Its name is the key both `Migrations.seedCategoryRecolours` and
/// [SeedData.shippedColorFor] match on — seeded rows get fresh uuids, so
/// there is nothing else to match — and a renamed default would quietly drop
/// out of any future seed data repair. Its colour carries none of that
/// weight: nothing keys off it, which makes it the one field that is safe to
/// hand over.
class CategoryColorSheet extends StatefulWidget {
  final CategoryModel category;

  const CategoryColorSheet({super.key, required this.category});

  @override
  State<CategoryColorSheet> createState() => _CategoryColorSheetState();
}

class _CategoryColorSheetState extends State<CategoryColorSheet> {
  late String _selectedColor = widget.category.color;

  /// The colour this category was seeded with, or null if it wasn't seeded
  /// (or has since been renamed, which breaks the name lookup).
  late final String? _shippedColor = SeedData.shippedColorFor(
    id: widget.category.id,
    type: widget.category.type,
    name: widget.category.name,
    isDefault: widget.category.isDefault,
  );

  Future<void> _save() async {
    final provider = context.read<CategoryProvider>();
    final loc = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);

    try {
      await provider.updateCategory(
        widget.category.copyWith(color: _selectedColor),
      );
      if (mounted) navigator.pop(_selectedColor);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.errorFailedToSave)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final colorValue = parseHexColor(_selectedColor);
    final canReset = _shippedColor != null && _shippedColor != _selectedColor;

    return FormSheet(
      title: loc.categoryColor,
      action: ElevatedButton(
        onPressed: _save,
        child: Text(loc.save),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The name is shown but not editable — this sheet exists
            // precisely because renaming a default is not on offer.
            Row(
              children: [
                TintedIcon(
                  icon: widget.category.iconData,
                  color: colorValue,
                ),
                const SizedBox(width: AppConstants.spacingLg),
                Expanded(
                  child: Text(
                    widget.category.name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingXxl),

            Text(loc.color, style: theme.textTheme.labelMedium),
            const SizedBox(height: AppConstants.spacingMd),
            ColorSwatchPicker(
              options: AppColors.swatchOptions,
              selected: _selectedColor,
              onSelected: (hex) => setState(() => _selectedColor = hex),
            ),

            // Only offered once the colour actually differs from the
            // shipped one, so the button never sits there doing nothing.
            if (canReset) ...[
              const SizedBox(height: AppConstants.spacingMd),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _selectedColor = _shippedColor!),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(loc.resetToDefaultColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
