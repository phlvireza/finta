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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CategoryForm(
          isIncome: isIncome,
          categoryToEdit: category,
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final bool isIncome;

  const _CategoryList({required this.isIncome});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CategoryProvider>();
    final categories =
        isIncome ? provider.incomeCategories : provider.expenseCategories;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppConstants.fabClearance),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];

        return ListTile(
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
        );
      },
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
