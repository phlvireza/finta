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

  /// Stop a template: deactivate it *and* cut the link from every occurrence
  /// it already posted.
  ///
  /// The posted transactions themselves are deliberately kept — the money was
  /// really spent, and unlike a goal or a debt there is nothing to give back.
  /// Only `recurringId` goes, because it is what makes a row render the repeat
  /// badge (`TransactionModel.isRecurring` is just `recurringId != null`).
  /// Left in place it points at a template that every screen filters out on
  /// `isActive`, so the badge would claim a schedule the user can no longer
  /// see, pause or resume.
  ///
  /// Both statements run in one transaction because `transactions.recurringId`
  /// has no foreign key, so nothing at the schema level would catch a
  /// half-applied stop.
  ///
  /// Callers must reload `TransactionProvider` afterwards — its in-memory
  /// lists still hold the pre-unlink copies. Nothing else needs reloading; no
  /// amount, date or account changed.
  Future<void> delete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'transactions',
          {'recurringId': null},
          where: 'recurringId = ?',
          whereArgs: [id],
        );
        await txn.update(
          'recurring_transactions',
          {'isActive': 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
    } catch (e) {
      throw DatabaseException('Failed to soft delete recurring transaction', cause: e);
    }
  }

  /// Erase the template row outright. Unlinks first for the same reason
  /// [delete] does — more urgently here, since the id would otherwise resolve
  /// to no row at all.
  Future<void> hardDelete(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.transaction((txn) async {
        await txn.update(
          'transactions',
          {'recurringId': null},
          where: 'recurringId = ?',
          whereArgs: [id],
        );
        await txn.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw DatabaseException('Failed to hard delete recurring transaction', cause: e);
    }
  }
}
