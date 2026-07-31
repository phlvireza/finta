import '../core/database/database_helper.dart';
import '../models/recurring_transaction_model.dart';
import '../core/exceptions/app_exceptions.dart';

/// Pure data-access class for the recurring_transactions table.
class RecurringRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<RecurringTransactionModel>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('recurring_transactions', orderBy: 'createdAt DESC');
      return maps.map((m) => RecurringTransactionModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all recurring transactions', cause: e);
    }
  }

  Future<List<RecurringTransactionModel>> getActive() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'recurring_transactions',
        where: 'isActive = 1',
        orderBy: 'createdAt DESC',
      );
      return maps.map((m) => RecurringTransactionModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get active recurring transactions', cause: e);
    }
  }

  Future<RecurringTransactionModel?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'recurring_transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return RecurringTransactionModel.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to get recurring transaction by id', cause: e);
    }
  }

  Future<void> insert(RecurringTransactionModel recurring) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('recurring_transactions', recurring.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert recurring transaction', cause: e);
    }
  }

  Future<void> update(RecurringTransactionModel recurring) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'recurring_transactions',
        recurring.toMap(),
        where: 'id = ?',
        whereArgs: [recurring.id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update recurring transaction', cause: e);
    }
  }

  Future<void> updateLastRunDate(String id, DateTime date) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'recurring_transactions',
        {'lastRunDate': date.toIso8601String().substring(0, 10)},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update last run date', cause: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'recurring_transactions',
        {'isActive': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Failed to soft delete recurring transaction', cause: e);
    }
  }

  Future<void> hardDelete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to hard delete recurring transaction', cause: e);
    }
  }
}
