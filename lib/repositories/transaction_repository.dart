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

  /// Sum of expense spend across several categories in one range — used
  /// by group/rollover budgets, which cover more than one category.
  Future<double> getCategoriesSumByDateRange(
    List<String> categoryIds,
    DateTime start,
    DateTime end,
  ) async {
    if (categoryIds.isEmpty) return 0;
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      final placeholders = List.filled(categoryIds.length, '?').join(',');
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as total FROM transactions '
        'WHERE categoryId IN ($placeholders) AND date >= ? AND date <= ? AND isTransfer = 0',
        [...categoryIds, startStr, endStr],
      );
      return (result.first['total'] as num).toDouble();
    } catch (e) {
      throw DatabaseException('Failed to get categories sum by date range', cause: e);
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

  /// Income/expense sums grouped by calendar month across [start]..[end] —
  /// unlike [getMonthlySums], not bound to a single calendar year, so it
  /// can power a rolling "last 12 months" cashflow chart that spans a
  /// year boundary.
  Future<List<Map<String, dynamic>>> getMonthlySumsInRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      return db.rawQuery(
        "SELECT strftime('%Y-%m', date) as ym, type, SUM(amount) as total "
        'FROM transactions WHERE date >= ? AND date <= ? AND isTransfer = 0 '
        "GROUP BY strftime('%Y-%m', date), type ORDER BY ym",
        [startStr, endStr],
      );
    } catch (e) {
      throw DatabaseException('Failed to get monthly sums in range', cause: e);
    }
  }

  /// A single category's spend grouped by calendar month across
  /// [start]..[end] — powers the category trend chart.
  Future<List<Map<String, dynamic>>> getCategoryMonthlySums(
    String categoryId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      return db.rawQuery(
        "SELECT strftime('%Y-%m', date) as ym, SUM(amount) as total FROM transactions "
        'WHERE categoryId = ? AND date >= ? AND date <= ? AND isTransfer = 0 '
        "GROUP BY strftime('%Y-%m', date) ORDER BY ym",
        [categoryId, startStr, endStr],
      );
    } catch (e) {
      throw DatabaseException('Failed to get category monthly sums', cause: e);
    }
  }

  /// Expense totals grouped by day across [start]..[end] — powers the
  /// spending heatmap calendar.
  Future<List<Map<String, dynamic>>> getDailyExpenseSums(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      return db.rawQuery(
        'SELECT date, SUM(amount) as total FROM transactions '
        "WHERE type = 'expense' AND isTransfer = 0 AND date >= ? AND date <= ? "
        'GROUP BY date',
        [startStr, endStr],
      );
    } catch (e) {
      throw DatabaseException('Failed to get daily expense sums', cause: e);
    }
  }

  /// The [limit] merchants with the highest total spend of [type] across
  /// [start]..[end], ranked descending.
  Future<List<Map<String, dynamic>>> getTopMerchants(
    String type,
    DateTime start,
    DateTime end, {
    int limit = 10,
  }) async {
    try {
      final db = await _dbHelper.database;
      final startStr = start.toIso8601String().substring(0, 10);
      final endStr = end.toIso8601String().substring(0, 10);
      return db.rawQuery(
        'SELECT merchant, SUM(amount) as total, COUNT(*) as cnt FROM transactions '
        "WHERE type = ? AND isTransfer = 0 AND merchant IS NOT NULL AND merchant != '' "
        'AND date >= ? AND date <= ? '
        'GROUP BY merchant ORDER BY total DESC LIMIT ?',
        [type, startStr, endStr, limit],
      );
    } catch (e) {
      throw DatabaseException('Failed to get top merchants', cause: e);
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

  /// Merchants seen before, ranked by how often they're used — powers the
  /// entry form's autocomplete. Empty [query] returns the most-used
  /// merchants overall (a reasonable "recent/frequent" default list).
  Future<List<String>> getMerchantSuggestions(String query, {int limit = 8}) async {
    try {
      final db = await _dbHelper.database;
      final sanitized = query.replaceAll('%', '').replaceAll('_', '');
      final maps = await db.rawQuery(
        'SELECT merchant, COUNT(*) as cnt FROM transactions '
        "WHERE merchant IS NOT NULL AND merchant != '' AND merchant LIKE ? "
        'GROUP BY merchant ORDER BY cnt DESC LIMIT ?',
        ['%$sanitized%', limit],
      );
      return maps.map((m) => m['merchant'] as String).toList();
    } catch (e) {
      throw DatabaseException('Failed to get merchant suggestions', cause: e);
    }
  }

  /// A category's last [limit] individual (non-transfer) transaction
  /// amounts, most recent first — the history an anomaly check compares a
  /// new entry against. Excludes [excludeId] so re-checking an existing
  /// transaction being edited doesn't compare it against itself.
  Future<List<double>> getRecentAmountsForCategory(
    String categoryId, {
    int limit = 20,
    String? excludeId,
  }) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'transactions',
        columns: ['amount'],
        where: excludeId != null
            ? 'categoryId = ? AND isTransfer = 0 AND id != ?'
            : 'categoryId = ? AND isTransfer = 0',
        whereArgs: excludeId != null ? [categoryId, excludeId] : [categoryId],
        orderBy: 'date DESC, createdAt DESC',
        limit: limit,
      );
      return maps.map((m) => (m['amount'] as num).toDouble()).toList();
    } catch (e) {
      throw DatabaseException('Failed to get recent amounts for category', cause: e);
    }
  }

  /// The category and account this merchant is most often paired with —
  /// used to pre-fill the rest of the form the moment a known merchant is
  /// picked, the "20 lines of SQL that feel like magic" trick.
  Future<({String categoryId, String accountId})?> getMerchantDefaults(String merchant) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.rawQuery(
        'SELECT categoryId, accountId, COUNT(*) as cnt FROM transactions '
        'WHERE merchant = ? AND isTransfer = 0 '
        'GROUP BY categoryId, accountId ORDER BY cnt DESC LIMIT 1',
        [merchant],
      );
      if (maps.isEmpty) return null;
      return (
        categoryId: maps.first['categoryId'] as String,
        accountId: maps.first['accountId'] as String,
      );
    } catch (e) {
      throw DatabaseException('Failed to get merchant defaults', cause: e);
    }
  }
}
