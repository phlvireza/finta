import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/category_provider.dart';
import '../../../models/category_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../categories/widgets/category_form.dart';
import '../../../widgets/form_sheet.dart';
import '../../../widgets/picker_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/category_display.dart';

/// Form field that opens a searchable bottom sheet for category selection.
class CategoryPicker extends StatelessWidget {
  final bool isIncome;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategorySelected;
  final FormFieldValidator<String>? validator;

  const CategoryPicker({
    super.key,
    required this.isIncome,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    this.validator,
  });

  void _openCategorySheet(BuildContext context, FormFieldState<String> state) {
    PickerSheet.show<void>(
      context,
      builder: (_) => _CategorySearchSheet(
        isIncome: isIncome,
        selectedCategoryId: selectedCategoryId,
        onSelected: (id) {
          state.didChange(id);
          onCategorySelected(id);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesProvider = context.watch<CategoryProvider>();
    final categories = isIncome
        ? categoriesProvider.incomeCategories
        : categoriesProvider.expenseCategories;

    CategoryModel? selectedCategory;
    try {
      selectedCategory = categories.firstWhere((c) => c.id == selectedCategoryId);
    } catch (_) {}

    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.category,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: AppConstants.spacingSm),
          FormField<String>(
            validator: validator,
            initialValue: selectedCategoryId,
            builder: (FormFieldState<String> state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openCategorySheet(context, state),
                    child: Container(
                      padding: const EdgeInsets.all(AppConstants.spacingMd),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        border: Border.all(
                          color: state.hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (selectedCategory != null) ...[
                            Icon(
                              selectedCategory.iconData,
                              color: selectedCategory.colorValue,
                              size: 24,
                            ),
                            const SizedBox(width: AppConstants.spacingMd),
                            Expanded(
                              child: Text(
                                categoryDisplayName(selectedCategory, loc),
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: Text(
                                loc.selectACategory,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ),
                          ],
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: theme.iconTheme.color,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: AppConstants.spacingXs),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
                      child: Text(
                        state.errorText!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategorySearchSheet extends StatefulWidget {
  final bool isIncome;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelected;

  const _CategorySearchSheet({
    required this.isIncome,
    this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  State<_CategorySearchSheet> createState() => _CategorySearchSheetState();
}

class _CategorySearchSheetState extends State<_CategorySearchSheet> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens the category form and, if it saved, selects the result straight
  /// away — creating a category from inside a picker is always a means to
  /// picking it, and leaving the user back on an unchanged-looking list
  /// made the creation read as if it had failed.
  Future<void> _createNewCategory({String? parentId}) async {
    final createdId = await FormSheet.show<String>(
      context,
      builder: (_) => CategoryForm(
        isIncome: widget.isIncome,
        initialParentId: parentId,
      ),
    );
    if (createdId == null || !mounted) return;
    widget.onSelected(createdId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesProvider = context.watch<CategoryProvider>();
    final allCategories = widget.isIncome
        ? categoriesProvider.incomeCategories
        : categoriesProvider.expenseCategories;

    final loc = AppLocalizations.of(context)!;

    final query = _searchController.text.toLowerCase();
    // Matched on both names: a seeded category is stored in English and
    // shown translated, so searching one alone misses half the ways a user
    // might reach for it.
    final filtered = query.isEmpty
        ? allCategories
        : allCategories
            .where((c) =>
                c.name.toLowerCase().contains(query) ||
                categoryDisplayName(c, loc).toLowerCase().contains(query))
            .toList();

    return PickerSheet(
      title: loc.selectACategory,
      pinnedHeader: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: loc.searchCategories,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      children: [
        // Create New Category Button
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, color: theme.colorScheme.onSecondary),
          ),
          title: Text(
            loc.createNewCategory,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () => _createNewCategory(),
        ),
        const Divider(),

        // Categories List — top-level categories followed immediately
        // by their own children, indented, rather than a flat
        // alphabetical/sortOrder mix that scatters a parent from its
        // sub-categories. Search still matches by name across both
        // levels, since [filtered] is a flat name-matched list.
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingXxl),
            child: Center(
              child: Text(
                loc.noCategoriesFound,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          ..._buildGroupedTiles(context, filtered, theme, loc),
      ],
    );
  }

  List<Widget> _buildGroupedTiles(
    BuildContext context,
    List<CategoryModel> filtered,
    ThemeData theme,
    AppLocalizations loc,
  ) {
    final filteredIds = filtered.map((c) => c.id).toSet();
    final topLevel = filtered.where((c) => c.parentId == null || !filteredIds.contains(c.parentId));
    final tiles = <Widget>[];
    for (final cat in topLevel) {
      tiles.add(_categoryTile(context, cat, theme, loc));
      for (final child in filtered.where((c) => c.parentId == cat.id)) {
        tiles.add(_categoryTile(context, child, theme, loc, indented: true));
      }
    }
    return tiles;
  }

  Widget _categoryTile(
    BuildContext context,
    CategoryModel cat,
    ThemeData theme,
    AppLocalizations loc, {
    bool indented = false,
  }) {
    final isSelected = cat.id == widget.selectedCategoryId;
    return Padding(
      padding: EdgeInsets.only(left: indented ? AppConstants.spacingXxxl : 0),
      child: ListTile(
        leading: Icon(cat.iconData, color: cat.colorValue),
        title: Text(categoryDisplayName(cat, loc)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Keyed off parentId rather than [indented]: a sub-category
            // whose parent fell outside the search results still renders
            // flush left, and the hierarchy is only 2 levels deep — it
            // can't take children of its own.
            if (cat.parentId == null)
              IconButton(
                icon: const Icon(Icons.playlist_add, size: 20),
                color: theme.colorScheme.onSurfaceVariant,
                tooltip: loc.createNewCategory,
                onPressed: () => _createNewCategory(parentId: cat.id),
              ),
            if (!cat.isDefault)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => FormSheet.show<String>(
                  context,
                  builder: (_) => CategoryForm(
                    isIncome: widget.isIncome,
                    categoryToEdit: cat,
                  ),
                ),
              ),
            if (isSelected) Icon(Icons.check, color: theme.colorScheme.primary),
          ],
        ),
        onTap: () => widget.onSelected(cat.id),
      ),
    );
  }
}

