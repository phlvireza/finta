import '../core/database/database_helper.dart';
import '../models/goal_model.dart';
import '../core/exceptions/app_exceptions.dart';

/// Pure data-access class for the goals table.
class GoalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<GoalModel>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('goals', orderBy: 'createdAt ASC');
      return maps.map((m) => GoalModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all goals', cause: e);
    }
  }

  Future<GoalModel?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('goals', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return GoalModel.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to get goal by id', cause: e);
    }
  }

  Future<void> insert(GoalModel goal) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('goals', goal.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert goal', cause: e);
    }
  }

  Future<void> update(GoalModel goal) async {
    try {
      final db = await _dbHelper.database;
      await db.update('goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
    } catch (e) {
      throw DatabaseException('Failed to update goal', cause: e);
    }
  }

  /// Archive a goal: it disappears from active lists but every historical
  /// contribution keeps a resolvable goal name.
  Future<void> archive(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.update('goals', {'isArchived': 1}, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to archive goal', cause: e);
    }
  }

  /// Bring an archived goal back into the active list.
  Future<void> unarchive(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.update('goals', {'isArchived': 0}, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to unarchive goal', cause: e);
    }
  }

  /// Count how many transactions still reference this goal.
  Future<int> countUsage(String id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM transactions WHERE goalId = ?',
        [id],
      );
      return result.first['c'] as int;
    } catch (e) {
      throw DatabaseException('Failed to count goal usage', cause: e);
    }
  }

  /// Permanently remove a goal. Only call when [countUsage] is 0 — callers
  /// are responsible for archiving instead when it isn't.
  Future<void> deleteUnused(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('goals', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to delete goal', cause: e);
    }
  }

  /// Permanently remove a goal *and* every transaction tagged with it — the
  /// "I created this by mistake" path, which has to give the money back.
  ///
  /// Both statements run in one transaction because `transactions.goalId` has
  /// no foreign key (it was added by `ALTER TABLE`, which can't declare one),
  /// so nothing at the schema level would catch a half-applied delete: the
  /// goal row would be gone and its contributions left pointing at an id that
  /// resolves to nothing, invisible in every screen.
  ///
  /// Callers must reload accounts, budgets and analytics afterwards —
  /// deleting expenses moves balances, and those are all derived.
  Future<void> deleteWithTransactions(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('transactions', where: 'goalId = ?', whereArgs: [id]);
        await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw DatabaseException('Failed to delete goal with transactions', cause: e);
    }
  }

  /// Amount saved toward every goal, in one query — a goal's progress is
  /// always derived from its tagged transactions (expense = contribution,
  /// income = withdrawal), never stored, so it can't drift out of sync
  /// with the transaction history.
  Future<Map<String, double>> getAllProgress() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        "SELECT goalId, SUM(CASE WHEN type = 'expense' THEN amount ELSE -amount END) as total "
        'FROM transactions WHERE goalId IS NOT NULL GROUP BY goalId',
      );
      return {
        for (final r in rows) r['goalId'] as String: (r['total'] as num).toDouble(),
      };
    } catch (e) {
      throw DatabaseException('Failed to get goal progress', cause: e);
    }
  }

  /// Net contribution total for each of the last [months] calendar months
  /// (oldest first), zero-filled for months with no activity — feeds the
  /// "projected completion date" estimate, which needs a fixed-length
  /// window rather than however many months happen to have rows.
  Future<List<double>> getRecentMonthlyContributions(String goalId, {int months = 3}) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        "SELECT strftime('%Y-%m', date) as ym, "
        "SUM(CASE WHEN type = 'expense' THEN amount ELSE -amount END) as total "
        'FROM transactions WHERE goalId = ? GROUP BY ym',
        [goalId],
      );
      final byMonth = <String, double>{
        for (final r in rows) r['ym'] as String: (r['total'] as num).toDouble(),
      };
      final now = DateTime.now();
      final result = <double>[];
      for (var i = months - 1; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i, 1);
        final key = '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
        result.add(byMonth[key] ?? 0);
      }
      return result;
    } catch (e) {
      throw DatabaseException('Failed to get recent monthly contributions', cause: e);
    }
  }
}
