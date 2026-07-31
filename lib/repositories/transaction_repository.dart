import '../core/database/database_helper.dart';
import '../models/transaction_model.dart';
import '../core/exceptions/app_exceptions.dart';

/// Pure data-access class for the transactions table.
class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<TransactionModel>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('transactions', orderBy: 'date DESC, createdAt DESC');
      return maps.map((m) => TransactionModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all transactions', cause: e);
    }
  }

  Future<TransactionModel?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return TransactionModel.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to get transaction by id', cause: e);
    }
  }

  Future<List<TransactionModel>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      final maps = await db.query(
        'transactions',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startStr, endStr],
        orderBy: 'date DESC, createdAt DESC',
      );
      return maps.map((m) => TransactionModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get transactions by date range', cause: e);
    }
  }

  Future<List<TransactionModel>> getByType(String type) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'transactions',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'date DESC, createdAt DESC',
      );
      return maps.map((m) => TransactionModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get transactions by type', cause: e);
    }
  }

  Future<List<TransactionModel>> getRecent(int limit) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'transactions',
        orderBy: 'date DESC, createdAt DESC',
        limit: limit,
      );
      return maps.map((m) => TransactionModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get recent transactions', cause: e);
    }
  }

  Future<double> getSumByTypeAndDateRange(
    String type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM transactions '
        'WHERE type = ? AND date >= ? AND date <= ? AND isTransfer = 0',
        [type, startStr, endStr],
      );
      return (result.first['total'] as num).toDouble();
    } catch (e) {
      throw DatabaseException('Failed to get sum by type and date range', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> getCategorySums(
    String type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      return db.rawQuery(
        'SELECT categoryId, SUM(amount) as total FROM transactions '
        'WHERE type = ? AND date >= ? AND date <= ? AND isTransfer = 0 '
        'GROUP BY categoryId ORDER BY total DESC',
        [type, startStr, endStr],
      );
    } catch (e) {
      throw DatabaseException('Failed to get category sums', cause: e);
    }
  }

  Future<double> getCategorySumByDateRange(
    String categoryId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM transactions '
        'WHERE categoryId = ? AND date >= ? AND date <= ? AND isTransfer = 0',
        [categoryId, startStr, endStr],
      );
      return (result.first['total'] as num).toDouble();
    } catch (e) {
      throw DatabaseException('Failed to get category sum by date range', cause: e);
    }
  }

  Future<List<Map<String, dynamic>>> getMonthlySums(int year) async {
    try {
      final db = await _dbHelper.database;
      final startStr = '$year-01-01';
      final endStr = '$year-12-31';
      return db.rawQuery(
        "SELECT strftime('%m', date) as month, type, SUM(amount) as total "
        'FROM transactions WHERE date >= ? AND date <= ? AND isTransfer = 0 '
        "GROUP BY strftime('%m', date), type ORDER BY month",
        [startStr, endStr],
      );
    } catch (e) {
      throw DatabaseException('Failed to get monthly sums', cause: e);
    }
  }

  Future<void> insert(TransactionModel transaction) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('transactions', transaction.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert transaction', cause: e);
    }
  }

  Future<void> update(TransactionModel transaction) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'transactions',
        transaction.toMap(),
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update transaction', cause: e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to delete transaction', cause: e);
    }
  }

  /// Insert several transactions atomically — used for a transfer's two
  /// linked legs, so a crash mid-write can never leave only one side of a
  /// transfer posted.
  Future<void> insertBatch(List<TransactionModel> transactions) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final t in transactions) {
          batch.insert('transactions', t.toMap());
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw DatabaseException('Failed to insert transaction batch', cause: e);
    }
  }

  /// Delete every leg of a transfer together — a transfer must never end
  /// up with only one of its two linked rows.
  Future<void> deleteTransferPair(String transferId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('transactions', where: 'transferId = ?', whereArgs: [transferId]);
    } catch (e) {
      throw DatabaseException('Failed to delete transfer', cause: e);
    }
  }

  Future<List<TransactionModel>> search(String query) async {
    try {
      final db = await _dbHelper.database;
      // Sanitize search query to prevent wildcards taking over
      final sanitizedQuery = query.replaceAll('%', '').replaceAll('_', '');
      if (sanitizedQuery.isEmpty) return [];

      final maps = await db.query(
        'transactions',
        where: 'note LIKE ?',
        whereArgs: ['%$sanitizedQuery%'],
        orderBy: 'date DESC, createdAt DESC',
      );
      return maps.map((m) => TransactionModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to search transactions', cause: e);
    }
  }

  /// Get all distinct years that have transaction data.
  Future<List<int>> getDistinctYears() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        "SELECT DISTINCT strftime('%Y', date) as year FROM transactions ORDER BY year DESC",
      );
      return result.map((m) => int.parse(m['year'] as String)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get distinct years', cause: e);
    }
  }
}
