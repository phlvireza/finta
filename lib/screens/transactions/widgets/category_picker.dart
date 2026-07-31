import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/category_provider.dart';
import '../../../models/category_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../categories/widgets/category_form.dart';
import '../../../l10n/app_localizations.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                                selectedCategory.name,
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

  void _createNewCategory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryForm(isIncome: widget.isIncome),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesProvider = context.watch<CategoryProvider>();
    final allCategories = widget.isIncome
        ? categoriesProvider.incomeCategories
        : categoriesProvider.expenseCategories;

    final query = _searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? allCategories
        : allCategories.where((c) => c.name.toLowerCase().contains(query)).toList();

    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        top: AppConstants.spacingLg,
        left: AppConstants.spacingLg,
        right: AppConstants.spacingLg,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Search Bar
            TextField(
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
            const SizedBox(height: AppConstants.spacingMd),
            
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
              onTap: _createNewCategory,
            ),
            const Divider(),
            
            // Categories List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        loc.noCategoriesFound,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final cat = filtered[index];
                        final isSelected = cat.id == widget.selectedCategoryId;
                        return ListTile(
                          leading: Icon(cat.iconData, color: cat.colorValue),
                          title: Text(cat.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!cat.isDefault)
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  color: theme.colorScheme.onSurfaceVariant,
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => CategoryForm(
                                        isIncome: widget.isIncome,
                                        categoryToEdit: cat,
                                      ),
                                    );
                                  },
                                ),
                              if (isSelected)
                                Icon(Icons.check, color: theme.colorScheme.primary),
                            ],
                          ),
                          onTap: () => widget.onSelected(cat.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

