import '../core/database/database_helper.dart';
import '../models/debt_model.dart';
import '../core/exceptions/app_exceptions.dart';

/// Pure data-access class for the debts table.
class DebtRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<DebtModel>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('debts', orderBy: 'createdAt ASC');
      return maps.map((m) => DebtModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all debts', cause: e);
    }
  }

  Future<DebtModel?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('debts', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return DebtModel.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to get debt by id', cause: e);
    }
  }

  Future<void> insert(DebtModel debt) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('debts', debt.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert debt', cause: e);
    }
  }

  Future<void> update(DebtModel debt) async {
    try {
      final db = await _dbHelper.database;
      await db.update('debts', debt.toMap(), where: 'id = ?', whereArgs: [debt.id]);
    } catch (e) {
      throw DatabaseException('Failed to update debt', cause: e);
    }
  }

  /// Archive a debt: it disappears from active lists but every historical
  /// repayment keeps a resolvable debt name.
  Future<void> archive(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.update('debts', {'isArchived': 1}, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to archive debt', cause: e);
    }
  }

  /// Bring an archived debt back into the active list.
  Future<void> unarchive(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.update('debts', {'isArchived': 0}, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to unarchive debt', cause: e);
    }
  }

  /// Count how many transactions still reference this debt.
  Future<int> countUsage(String id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM transactions WHERE debtId = ?',
        [id],
      );
      return result.first['c'] as int;
    } catch (e) {
      throw DatabaseException('Failed to count debt usage', cause: e);
    }
  }

  /// Permanently remove a debt. Only call when [countUsage] is 0 — callers
  /// are responsible for archiving instead when it isn't.
  Future<void> deleteUnused(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('debts', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException('Failed to delete debt', cause: e);
    }
  }

  /// Permanently remove a debt *and* every repayment tagged with it — the
  /// "I created this by mistake" path, which has to give the money back.
  ///
  /// One transaction for the same reason as `GoalRepository`: `debtId` has no
  /// foreign key, so a half-applied delete leaves repayments pointing at a
  /// debt that no longer exists and nothing in the schema objects.
  ///
  /// Callers must reload accounts, budgets and analytics afterwards —
  /// deleting repayments moves balances, and those are all derived.
  Future<void> deleteWithTransactions(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('transactions', where: 'debtId = ?', whereArgs: [id]);
        await txn.delete('debts', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw DatabaseException('Failed to delete debt with transactions', cause: e);
    }
  }

  /// Total repaid so far for every debt, in one query. A repayment
  /// transaction's `amount` is always stored positive regardless of debt
  /// direction (an expense for a debt you owe, an income for one owed to
  /// you) — outstanding balance is simply `principal - repaid`.
  Future<Map<String, double>> getAllRepaid() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        'SELECT debtId, SUM(amount) as total FROM transactions '
        'WHERE debtId IS NOT NULL GROUP BY debtId',
      );
      return {
        for (final r in rows) r['debtId'] as String: (r['total'] as num).toDouble(),
      };
    } catch (e) {
      throw DatabaseException('Failed to get debt repayments', cause: e);
    }
  }
}
