import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../repositories/category_repository.dart';

/// Manages category state — load, create, update, delete.
class CategoryProvider extends ChangeNotifier {
  final CategoryRepository _repository;
  static const _uuid = Uuid();

  CategoryProvider({CategoryRepository? repository})
      : _repository = repository ?? CategoryRepository();

  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<CategoryModel> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Selectable expense categories — excludes archived and system-owned
  /// ones (e.g. the Transfer category) so a user can't pick a category
  /// they've already removed from active use, or one they never created.
  List<CategoryModel> get expenseCategories =>
      _categories.where((c) => c.isExpense && !c.isArchived && !c.isSystem).toList();

  /// Selectable income categories — excludes archived and system-owned ones.
  List<CategoryModel> get incomeCategories =>
      _categories.where((c) => c.isIncome && !c.isArchived && !c.isSystem).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Load all categories from the database.
  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await _repository.getAll();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get a category by ID.
  CategoryModel? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Create a new custom category.
  Future<void> addCategory({
    required String name,
    required String type,
    required String icon,
    required String color,
  }) async {
    try {
      final sortOrder = await _repository.getMaxSortOrder(type);
      final category = CategoryModel(
        id: _uuid.v4(),
        name: name,
        type: type,
        icon: icon,
        color: color,
        isDefault: false,
        sortOrder: sortOrder,
        createdAt: DateTime.now(),
      );

      await _repository.insert(category);
      _categories.add(category);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing category.
  Future<void> updateCategory(CategoryModel category) async {
    try {
      await _repository.update(category);
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = category;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// How many transactions still reference this category — used by the UI
  /// to decide whether removal will archive (history preserved) or delete.
  Future<int> countUsage(String id) => _repository.countUsage(id);

  /// Remove a category (only custom categories). If any transaction still
  /// references it, it is archived instead of deleted so history is never
  /// lost as a side effect of a settings change.
  Future<void> deleteCategory(String id) async {
    try {
      final category = getCategoryById(id);
      if (category == null || category.isDefault) return;

      final usage = await _repository.countUsage(id);
      if (usage > 0) {
        await _repository.archive(id);
      } else {
        await _repository.deleteUnused(id);
      }
      // Reload rather than mutate in place: an archived row must stay in
      // _categories (with isArchived: true) so getCategoryById can still
      // resolve it for old transactions.
      await loadCategories();
    } catch (e) {
      rethrow;
    }
  }
}
