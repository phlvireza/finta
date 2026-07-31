import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/account_model.dart';
import '../repositories/account_repository.dart';

/// Manages account state — load, create, update, archive, and the
/// balance-per-account map that the net worth card / carousel read from.
class AccountProvider extends ChangeNotifier {
  final AccountRepository _repository;
  static const _uuid = Uuid();

  AccountProvider({AccountRepository? repository})
      : _repository = repository ?? AccountRepository();

  List<AccountModel> _accounts = [];
  Map<String, double> _balances = {};
  bool _isLoading = false;
  String? _error;

  List<AccountModel> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Selectable accounts — excludes archived ones.
  List<AccountModel> get activeAccounts =>
      _accounts.where((a) => !a.isArchived).toList();

  double balanceOf(String accountId) => _balances[accountId] ?? 0;

  /// Sum of every included-in-total account's balance — accounts (like a
  /// credit card mid-cycle) still count here even when their balance is
  /// negative, since a debt is part of net worth too.
  double get netWorth => _accounts
      .where((a) => a.includeInTotal)
      .fold(0.0, (sum, a) => sum + balanceOf(a.id));

  /// Sum of balances for accounts you could actually spend right now —
  /// same as [netWorth] but with credit cards excluded, since a credit
  /// line isn't cash on hand.
  double get availableCash => _accounts
      .where((a) => a.includeInTotal && !a.isCreditCard)
      .fold(0.0, (sum, a) => sum + balanceOf(a.id));

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadAccounts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _accounts = await _repository.getAll();
      _balances = await _repository.getAllBalances();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  AccountModel? getAccountById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<AccountModel> addAccount({
    required String name,
    required String type,
    required double openingBalance,
    required String color,
    double? creditLimit,
    bool includeInTotal = true,
  }) async {
    final sortOrder = await _repository.getMaxSortOrder();
    final account = AccountModel(
      id: _uuid.v4(),
      name: name,
      type: type,
      openingBalance: openingBalance,
      color: color,
      creditLimit: creditLimit,
      includeInTotal: includeInTotal,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );

    await _repository.insert(account);
    await loadAccounts();
    return account;
  }

  Future<void> updateAccount(AccountModel account) async {
    await _repository.update(account);
    await loadAccounts();
  }

  /// How many transactions still reference this account — used by the UI
  /// to decide whether removal is safe or should archive instead.
  Future<int> countUsage(String id) => _repository.countUsage(id);

  Future<void> archiveAccount(String id) async {
    await _repository.archive(id);
    await loadAccounts();
  }
}
