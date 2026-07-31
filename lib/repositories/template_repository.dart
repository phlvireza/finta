import '../core/database/database_helper.dart';
import '../models/template_model.dart';
import '../core/exceptions/app_exceptions.dart';

/// Pure data-access class for the templates table.
class TemplateRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<TemplateModel>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('templates', orderBy: 'sortOrder ASC');
      return maps.map((m) => TemplateModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all templates', cause: e);
    }
  }

  Future<void> insert(TemplateModel template) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('templates', template.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert template', cause: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('templates', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to delete template', cause: e);
    }
  }

  Future<int> getMaxSortOrder() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COALESCE(MAX(sortOrder), -1) as maxOrder FROM templates',
      );
      return (result.first['maxOrder'] as int) + 1;
    } catch (e) {
      throw DatabaseException('Failed to get max sort order', cause: e);
    }
  }
}
