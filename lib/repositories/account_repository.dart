import '../core/database/database_helper.dart';
import '../models/account_model.dart';
import '../core/exceptions/app_exceptions.dart';

/// Pure data-access class for the accounts table.
class AccountRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<AccountModel>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('accounts', orderBy: 'sortOrder ASC');
      return maps.map((m) => AccountModel.fromMap(m)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get all accounts', cause: e);
    }
  }

  Future<AccountModel?> getById(String id) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return AccountModel.fromMap(maps.first);
    } catch (e) {
      throw DatabaseException('Failed to get account by id', cause: e);
    }
  }

  Future<void> insert(AccountModel account) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('accounts', account.toMap());
    } catch (e) {
      throw DatabaseException('Failed to insert account', cause: e);
    }
  }

  Future<void> update(AccountModel account) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'accounts',
        account.toMap(),
        where: 'id = ?',
        whereArgs: [account.id],
      );
    } catch (e) {
      throw DatabaseException('Failed to update account', cause: e);
    }
  }

  /// Archive an account: it disappears from pickers but every historical
  /// transaction keeps a resolvable name and its balance stays computable.
  Future<void> archive(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'accounts',
        {'isArchived': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw DatabaseException('Failed to archive account', cause: e);
    }
  }

  /// Count how many transactions still reference this account.
  Future<int> countUsage(String id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM transactions WHERE accountId = ?',
        [id],
      );
      return result.first['c'] as int;
    } catch (e) {
      throw DatabaseException('Failed to count account usage', cause: e);
    }
  }

  Future<int> getMaxSortOrder() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COALESCE(MAX(sortOrder), -1) as maxOrder FROM accounts',
      );
      return (result.first['maxOrder'] as int) + 1;
    } catch (e) {
      throw DatabaseException('Failed to get max sort order', cause: e);
    }
  }

  /// Current balance for a single account: opening balance plus every
  /// income transaction on it, minus every expense transaction on it.
  /// Transfers don't need special handling here — a transfer's two legs
  /// are ordinary income/expense rows on their respective accounts, so
  /// this formula naturally moves money between accounts without double
  /// counting. (Transfers ARE excluded from income/expense *reporting*
  /// elsewhere via `isTransfer = 0` — that's a separate concern from an
  /// account's own balance.)
  Future<double> getBalance(String accountId) async {
    final balances = await getBalancesFor([accountId]);
    return balances[accountId] ?? 0;
  }

  /// Balances for every account in one query — avoids N round trips for
  /// the account carousel / net worth card.
  Future<Map<String, double>> getAllBalances() async {
    try {
      final db = await _dbHelper.database;
      final accounts = await db.query('accounts', columns: ['id', 'openingBalance']);
      final sums = await db.rawQuery(
        'SELECT accountId, type, SUM(amount) as total FROM transactions '
        'GROUP BY accountId, type',
      );

      final balances = <String, double>{
        for (final a in accounts) a['id'] as String: (a['openingBalance'] as num).toDouble(),
      };
      for (final row in sums) {
        final accountId = row['accountId'] as String?;
        if (accountId == null || !balances.containsKey(accountId)) continue;
        final total = (row['total'] as num).toDouble();
        balances[accountId] = balances[accountId]! +
            (row['type'] == 'income' ? total : -total);
      }
      return balances;
    } catch (e) {
      throw DatabaseException('Failed to get account balances', cause: e);
    }
  }

  Future<Map<String, double>> getBalancesFor(List<String> accountIds) async {
    final all = await getAllBalances();
    return {for (final id in accountIds) id: all[id] ?? 0};
  }
}
