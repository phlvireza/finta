import '../../models/budget_model.dart';

/// Which category a new expense logged from [budget]'s detail screen should
/// start with — and, when that can't be decided for the user, which of the
/// budget's categories to offer instead.
///
/// A budget's spending is matched against its `categoryIds` literally
/// (`BudgetProvider._spentFor`), so anything prefilled from that list is
/// guaranteed to land inside the budget the user is looking at. An 'overall'
/// budget has no list — every expense counts toward it — so it prefills
/// nothing rather than picking a category on the user's behalf.
///
/// [selectableCategoryIds] is what `CategoryProvider.expenseCategories` can
/// actually resolve. A budget outlives an archived category, and prefilling an
/// id the picker renders blank for looks like an unset field with no
/// explanation — the same trap `ContributeToGoalSheet` guards against.
///
/// Returns the id to prefill, or the shortlist to ask about. Never both: a
/// non-empty `choices` means the caller must ask first.
({String? categoryId, List<String> choices}) resolveBudgetEntryCategory({
  required BudgetModel budget,
  required Set<String> selectableCategoryIds,
}) {
  if (budget.scope == 'overall') {
    return (categoryId: null, choices: const <String>[]);
  }

  final usable =
      budget.categoryIds.where(selectableCategoryIds.contains).toList();

  if (usable.length == 1) {
    return (categoryId: usable.single, choices: const <String>[]);
  }
  if (usable.length > 1) {
    return (categoryId: null, choices: usable);
  }
  // Archived away, or a malformed budget with no links at all. Open the plain
  // form rather than prefill something misleading.
  return (categoryId: null, choices: const <String>[]);
}
