import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/category_model.dart';
import '../../core/constants/app_constants.dart';
import 'widgets/category_form.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/form_sheet.dart';
import '../../l10n/app_localizations.dart';

/// Screen to list, create, edit, and delete custom categories.
class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.manageCategories),
          bottom: TabBar(
            tabs: [
              Tab(text: loc.expense),
              Tab(text: loc.income),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CategoryList(isIncome: false),
            _CategoryList(isIncome: true),
          ],
        ),
        floatingActionButton: Builder(
          builder: (fabContext) => FloatingActionButton(
            heroTag: null,
            onPressed: () {
              // Default to the currently selected tab type
              final index = DefaultTabController.of(fabContext).index;
              _showCategoryForm(context, isIncome: index == 1);
            },
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  static void _showCategoryForm(
    BuildContext context, {
    required bool isIncome,
    CategoryModel? category,
  }) {
    FormSheet.show<String>(
      context,
      builder: (_) => CategoryForm(
        isIncome: isIncome,
        categoryToEdit: category,
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final bool isIncome;

  const _CategoryList({required this.isIncome});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final categories =
        isIncome ? provider.incomeCategories : provider.expenseCategories;

    // Top-level categories first, each immediately followed by its own
    // children — a flat sortOrder list would otherwise scatter a parent
    // from its sub-categories.
    final topLevel = categories.where((c) => c.parentId == null).toList();
    final orphanParentIds = categories.map((c) => c.id).toSet();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppConstants.fabClearance),
      itemCount: topLevel.length,
      itemBuilder: (context, index) {
        final parent = topLevel[index];
        final children = categories.where((c) => c.parentId == parent.id).toList();
        // Guard against a child whose parent got archived/removed out from
        // under it — still show it, just without indentation, instead of
        // silently dropping it from the list.
        final orphanChildren = categories
            .where((c) => c.parentId != null && !orphanParentIds.contains(c.parentId))
            .toList();

        return Column(
          children: [
            _CategoryTile(category: parent, isIncome: isIncome),
            for (final child in children)
              _CategoryTile(category: child, isIncome: isIncome, indented: true),
            if (index == topLevel.length - 1)
              for (final orphan in orphanChildren)
                _CategoryTile(category: orphan, isIncome: isIncome),
          ],
        );
      },
    );
  }

}

class _CategoryTile extends StatelessWidget {
  final CategoryModel category;
  final bool isIncome;
  final bool indented;

  const _CategoryTile({
    required this.category,
    required this.isIncome,
    this.indented = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(left: indented ? AppConstants.spacingXxxl : 0),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.colorValue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
          child: Icon(category.iconData, color: category.colorValue),
        ),
        title: Text(category.name),
        subtitle: category.isDefault
            ? Text('Default', style: theme.textTheme.labelSmall)
            : null,
        trailing: category.isDefault
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => ManageCategoriesScreen._showCategoryForm(
                      context,
                      isIncome: isIncome,
                      category: category,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: theme.colorScheme.error,
                    onPressed: () => _deleteCategory(context, category),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, CategoryModel category) async {
    final loc = AppLocalizations.of(context)!;
    final categoryProvider = context.read<CategoryProvider>();
    final usage = await categoryProvider.countUsage(category.id);
    if (!context.mounted) return;

    final isArchiving = usage > 0;
    final confirmed = await ConfirmDialog.show(
      context,
      title: isArchiving ? loc.archiveCategory : loc.delete,
      message: isArchiving
          ? loc.confirmArchiveCategory(category.name, usage)
          : loc.confirmDeleteCategory(category.name),
      confirmText: isArchiving ? loc.archive : loc.delete,
    );

    if (confirmed && context.mounted) {
      try {
        await categoryProvider.deleteCategory(category.id);

        if (context.mounted) {
          final settings = context.read<SettingsProvider>();
          context.read<TransactionProvider>().loadTransactions(payday: settings.payday);
          context.read<BudgetProvider>().loadBudgets(payday: settings.payday);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.errorFailedToDelete)),
          );
        }
      }
    }
  }
}
