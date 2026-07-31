import 'package:flutter/material.dart';
import '../../models/budget_model.dart';
import '../../providers/category_provider.dart';
import '../../l10n/app_localizations.dart';

/// Resolves the title/icon/color a budget should render with, regardless
/// of scope — a single category, a named group of categories, or every
/// expense category. Keeps that branching out of every widget that shows
/// a budget (progress bar, dashboard overview, chart legend, ...).
({String title, IconData icon, Color color}) resolveBudgetDisplay({
  required BudgetModel budget,
  required CategoryProvider categories,
  required AppLocalizations loc,
  required Color fallbackColor,
}) {
  switch (budget.scope) {
    case 'overall':
      return (
        title: budget.name ?? loc.overallBudget,
        icon: Icons.account_balance_wallet,
        color: fallbackColor,
      );
    case 'group':
      final firstCategory =
          budget.categoryIds.isNotEmpty ? categories.getCategoryById(budget.categoryIds.first) : null;
      return (
        title: budget.name ?? loc.groupBudget,
        icon: Icons.folder_outlined,
        color: firstCategory?.colorValue ?? fallbackColor,
      );
    case 'category':
    default:
      final category =
          budget.categoryIds.isNotEmpty ? categories.getCategoryById(budget.categoryIds.first) : null;
      return (
        title: category?.name ?? loc.unknown,
        icon: category?.iconData ?? Icons.category,
        color: category?.colorValue ?? fallbackColor,
      );
  }
}
