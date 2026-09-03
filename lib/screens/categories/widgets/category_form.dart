import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/category_provider.dart';
import '../../../models/category_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/form_sheet.dart';
import 'icon_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/color_swatch_picker.dart';

/// Form for creating or editing a category.
///
/// Pops with the id of the saved category (null if dismissed), so a caller
/// that opened it from a picker can select the result immediately.
class CategoryForm extends StatefulWidget {
  final bool isIncome;
  final CategoryModel? categoryToEdit;

  /// Pre-selects the parent for a brand-new category, so "add a
  /// sub-category under this one" arrives at the form already set up.
  final String? initialParentId;

  const CategoryForm({
    super.key,
    required this.isIncome,
    this.categoryToEdit,
    this.initialParentId,
  });

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedIcon = 'category';
  String _selectedColor = '#C87941';
  String? _parentId;
  bool _autoValidate = false;

  /// A seeded category can be recoloured but not otherwise reshaped.
  ///
  /// Name is locked because seed-data migrations find these rows by name
  /// (see `Migrations.v10`) — a rename would silently opt the row out of
  /// any future fix. Parent and icon are locked because the seeded set is
  /// meant to stay recognisable across installs; colour is the one part
  /// that is purely the user's taste.
  bool get _isSeeded => widget.categoryToEdit?.isDefault ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.categoryToEdit != null) {
      _nameController.text = widget.categoryToEdit!.name;
      _selectedIcon = widget.categoryToEdit!.icon;
      _selectedColor = widget.categoryToEdit!.color;
      _parentId = widget.categoryToEdit!.parentId;
    } else {
      _parentId = widget.initialParentId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final provider = context.read<CategoryProvider>();
    final loc = AppLocalizations.of(context)!;

    try {
      final String savedId;
      if (widget.categoryToEdit != null) {
        final updated = widget.categoryToEdit!.copyWith(
          name: name,
          icon: _selectedIcon,
          color: _selectedColor,
          parentId: _parentId,
          clearParentId: _parentId == null,
        );
        await provider.updateCategory(updated);
        savedId = updated.id;
      } else {
        final created = await provider.addCategory(
          name: name,
          type: widget.isIncome ? 'income' : 'expense',
          icon: _selectedIcon,
          color: _selectedColor,
          parentId: _parentId,
        );
        savedId = created.id;
      }

      if (mounted) {
        Navigator.of(context).pop(savedId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.errorFailedToSave)), // Using new translation key
        );
      }
    }
  }

  Future<void> _pickIcon() async {
    final iconName = await showDialog<String>(
      context: context,
      builder: (_) => const IconPickerDialog(),
    );
    if (iconName != null) {
      setState(() => _selectedIcon = iconName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hexColor = _selectedColor.replaceAll('#', '');
    final colorValue = Color(int.parse('FF$hexColor', radix: 16));
    final loc = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      autovalidateMode: _autoValidate ? AutovalidateMode.always : AutovalidateMode.disabled,
      child: FormSheet(
        title: widget.categoryToEdit != null ? loc.editCategory : loc.addCategory,
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
            // Icon and Name Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _isSeeded ? null : _pickIcon,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorValue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      border: Border.all(color: colorValue),
                    ),
                    child: Icon(
                      CategoryModel.availableIcons[_selectedIcon],
                      color: colorValue,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingLg),
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    enabled: !_isSeeded,
                    decoration: InputDecoration(
                      labelText: loc.categoryName,
                      hintText: '',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        borderSide: BorderSide(color: theme.colorScheme.error),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    maxLength: 30, // Input validation: Name length
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return loc.pleaseEnterName;

                      // Input validation: Duplicate check
                      final provider = context.read<CategoryProvider>();
                      final isDuplicate = provider.categories.any((c) =>
                        c.name.toLowerCase() == val.trim().toLowerCase() &&
                        c.id != widget.categoryToEdit?.id &&
                        c.type == (widget.isIncome ? 'income' : 'expense')
                      );
                      if (isDuplicate) return loc.categoryAlreadyExists;

                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingXxl),

            // Says why the fields above are greyed out. Without it a
            // disabled name field just reads as broken.
            if (_isSeeded) ...[
              Text(
                loc.defaultCategoryColorOnly,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXxl),
            ],

            // Parent category — sits directly under the name because it is
            // a structural choice (it decides where the category lands in
            // every picker), not decoration like the colour below. It used
            // to be the last field before the button, which on a phone with
            // the keyboard up put it below the fold entirely.
            //
            // Only 2 levels are allowed, so a category that already has
            // children of its own can't also become one (that would make
            // its children grandchildren of its new parent), and only
            // top-level categories are valid choices.
            Builder(builder: (context) {
              // Seeded categories keep the shape they shipped with, so
              // there is nothing to choose here.
              if (_isSeeded) return const SizedBox.shrink();

              final provider = context.watch<CategoryProvider>();
              final selfId = widget.categoryToEdit?.id;
              final hasChildren =
                  selfId != null && provider.categories.any((c) => c.parentId == selfId);
              if (hasChildren) return const SizedBox.shrink();

              final parentOptions = provider.categories.where((c) =>
                  c.type == (widget.isIncome ? 'income' : 'expense') &&
                  c.parentId == null &&
                  !c.isSystem &&
                  !c.isArchived &&
                  c.id != selfId);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.parentCategoryOptional, style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppConstants.spacingSm),
                  DropdownButtonFormField<String?>(
                    initialValue: _parentId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(loc.noneTopLevel)),
                      ...parentOptions.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _parentId = val),
                  ),
                  const SizedBox(height: AppConstants.spacingXxl),
                ],
              );
            }),

            // Color Picker
            Text(loc.color, style: theme.textTheme.labelMedium),
            const SizedBox(height: AppConstants.spacingMd),
            ColorSwatchPicker(
              selected: _selectedColor,
              onChanged: (hex) => setState(() => _selectedColor = hex),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
