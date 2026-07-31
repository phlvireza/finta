import '../core/database/database_helper.dart';
import '../models/budget_model.dart';
import '../core/exceptions/app_exceptions.dart';

/// Pure data-access class for the budgets table.
class BudgetRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<BudgetModel>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('budgets', orderBy: 'createdAt ASC');
      return maps.map((m) => BudgetModel.fromMap(m)).toList();
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
      return maps.map((m) => BudgetModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get active budgets', cause: e);
    }
  }

  Future<BudgetModel?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('budgets', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return BudgetModel.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to get budget by id', cause: e);
    }
  }

  Future<BudgetModel?> getByCategoryId(String categoryId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'budgets',
        where: 'categoryId = ?',
        whereArgs: [categoryId],
      );
      if (maps.isEmpty) return null;
      return BudgetModel.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to get budget by category id', cause: e);
    }
  }

  Future<void> insert(BudgetModel budget) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('budgets', budget.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert budget', cause: e);
    }
  }

  Future<void> update(BudgetModel budget) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'budgets',
        budget.toMap(),
        where: 'id = ?',
        whereArgs: [budget.id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update budget', cause: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to delete budget', cause: e);
    }
  }
}
