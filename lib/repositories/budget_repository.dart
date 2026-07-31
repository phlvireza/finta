import '../core/database/database_helper.dart';
import '../models/budget_model.dart';
import '../core/exceptions/app_exceptions.dart';

/// Pure data-access class for the budgets table (+ its budget_categories
/// join table).
class BudgetRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<BudgetModel>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('budgets', orderBy: 'createdAt ASC');
      return _attachCategories(maps.map((m) => BudgetModel.fromMap(m)).toList());
    } catch (e) {
      throw DatabaseException('Failed to get all budgets', cause: e);
    }
  }

  Future<List<BudgetModel>> getActive() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'budgets',
        where: 'isActive = 1',
        orderBy: 'createdAt ASC',
      );
      return _attachCategories(maps.map((m) => BudgetModel.fromMap(m)).toList());
    } catch (e) {
      throw DatabaseException('Failed to get active budgets', cause: e);
    }
  }

  Future<BudgetModel?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('budgets', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      final attached = await _attachCategories([BudgetModel.fromMap(maps.first)]);
      return attached.first;
    } catch (e) {
      throw DatabaseException('Failed to get budget by id', cause: e);
    }
  }

  /// Every active budget that covers [categoryId] — a category-scoped
  /// budget for it directly, or a group budget that includes it.
  Future<List<BudgetModel>> getForCategory(String categoryId) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        'SELECT b.* FROM budgets b '
        'JOIN budget_categories bc ON bc.budgetId = b.id '
        'WHERE bc.categoryId = ? AND b.isActive = 1',
        [categoryId],
      );
      return _attachCategories(rows.map((m) => BudgetModel.fromMap(m)).toList());
    } catch (e) {
      throw DatabaseException('Failed to get budgets for category', cause: e);
    }
  }

  Future<void> insert(BudgetModel budget) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.insert('budgets', budget.toMap());
        await _writeCategoryLinks(txn, budget);
      });
    } catch (e) {
      throw DatabaseException('Failed to insert budget', cause: e);
    }
  }

  Future<void> update(BudgetModel budget) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'budgets',
          budget.toMap(),
          where: 'id = ?',
          whereArgs: [budget.id],
        );
        await txn.delete('budget_categories', where: 'budgetId = ?', whereArgs: [budget.id]);
        await _writeCategoryLinks(txn, budget);
      });
    } catch (e) {
      throw DatabaseException('Failed to update budget', cause: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('budget_categories', where: 'budgetId = ?', whereArgs: [id]);
        await txn.delete('budgets', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw DatabaseException('Failed to delete budget', cause: e);
    }
  }

  Future<void> _writeCategoryLinks(dynamic txn, BudgetModel budget) async {
    if (budget.categoryIds.isEmpty) return;
    final batch = txn.batch();
    for (final categoryId in budget.categoryIds) {
      batch.insert('budget_categories', {'budgetId': budget.id, 'categoryId': categoryId});
    }
    await batch.commit(noResult: true);
  }

  Future<List<BudgetModel>> _attachCategories(List<BudgetModel> budgets) async {
    if (budgets.isEmpty) return budgets;
    final db = await _dbHelper.database;
    final ids = budgets.map((b) => b.id).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT budgetId, categoryId FROM budget_categories WHERE budgetId IN ($placeholders)',
      ids,
    );
    final byBudget = <String, List<String>>{};
    for (final row in rows) {
      byBudget.putIfAbsent(row['budgetId'] as String, () => []).add(row['categoryId'] as String);
    }
    return budgets.map((b) => b.copyWith(categoryIds: byBudget[b.id] ?? [])).toList();
  }
}
