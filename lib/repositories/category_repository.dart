import '../core/database/database_helper.dart';
import '../models/category_model.dart';
import '../core/exceptions/app_exceptions.dart';

/// Pure data-access class for the categories table.
class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<CategoryModel>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('categories', orderBy: 'sortOrder ASC');
      return maps.map((m) => CategoryModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all categories', cause: e);
    }
  }

  Future<List<CategoryModel>> getByType(String type) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'sortOrder ASC',
      );
      return maps.map((m) => CategoryModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get categories by type', cause: e);
    }
  }

  Future<CategoryModel?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return CategoryModel.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to get category by id', cause: e);
    }
  }

  Future<void> insert(CategoryModel category) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('categories', category.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert category', cause: e);
    }
  }

  Future<void> update(CategoryModel category) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'categories',
        category.toMap(),
        where: 'id = ?',
        whereArgs: [category.id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update category', cause: e);
    }
  }

  /// Count how many transactions still reference this category.
  Future<int> countUsage(String id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM transactions WHERE categoryId = ?',
        [id],
      );
      return result.first['c'] as int;
    } catch (e) {
      throw DatabaseException('Failed to count category usage', cause: e);
    }
  }

  /// Archive a category: it disappears from pickers but every historical
  /// transaction keeps a resolvable name and icon. Related budgets and
  /// recurring templates are deactivated (never deleted) since a budget or
  /// template for a category you can no longer spend on is meaningless.
  Future<void> archive(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'categories',
          {'isArchived': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.update(
          'budgets',
          {'isActive': 0},
          where: 'categoryId = ?',
          whereArgs: [id],
        );
        await txn.update(
          'recurring_transactions',
          {'isActive': 0},
          where: 'categoryId = ?',
          whereArgs: [id],
        );
      });
    } catch (e) {
      throw DatabaseException('Failed to archive category', cause: e);
    }
  }

  /// Permanently remove a category. Only call when [countUsage] is 0 —
  /// callers are responsible for archiving instead when it isn't.
  Future<void> deleteUnused(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('budgets', where: 'categoryId = ?', whereArgs: [id]);
        await txn.delete('recurring_transactions', where: 'categoryId = ?', whereArgs: [id]);
        await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw DatabaseException('Failed to delete category', cause: e);
    }
  }

  Future<int> getMaxSortOrder(String type) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COALESCE(MAX(sortOrder), -1) as maxOrder FROM categories WHERE type = ?',
        [type],
      );
      return (result.first['maxOrder'] as int) + 1;
    } catch (e) {
      throw DatabaseException('Failed to get max sort order', cause: e);
    }
  }
}
