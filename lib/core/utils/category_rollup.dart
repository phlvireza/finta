import '../../models/category_model.dart';
import '../../providers/analytics_provider.dart';

/// Rolls child (sub-)category totals up into their parent's entry, so the
/// default analytics view answers "how much on Lifestyle" without forcing
/// the user to mentally sum Entertainment + Shopping + Dining themselves.
/// A category with no parent (or an orphaned/archived parent) keeps its
/// own entry unchanged.
///
/// Takes a plain lookup function rather than `CategoryProvider` directly so
/// this stays a pure function of its inputs — easy to unit test, and the
/// only place that needs to know about the provider is the call site.
List<CategoryAnalytics> rollUpToParents(
  List<CategoryAnalytics> data,
  CategoryModel? Function(String id) getCategoryById,
) {
  final totals = <String, double>{};
  for (final d in data) {
    final category = getCategoryById(d.categoryId);
    final parent = category?.parentId != null ? getCategoryById(category!.parentId!) : null;
    final targetId = parent?.id ?? d.categoryId;
    totals[targetId] = (totals[targetId] ?? 0) + d.total;
  }

  final total = totals.values.fold<double>(0, (a, b) => a + b);
  final result = totals.entries
      .map((e) => CategoryAnalytics(
            categoryId: e.key,
            total: e.value,
            percentage: total > 0 ? e.value / total : 0,
          ))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return result;
}
