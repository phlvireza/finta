import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';
import '../repositories/debt_repository.dart';
import '../repositories/transaction_repository.dart';

/// Manages debt state — load, create, update, archive, and the
/// derived-from-transactions repaid/outstanding map debt cards read from.
class DebtProvider extends ChangeNotifier {
  final DebtRepository _repository;

  /// Held so the detail screen can list the repayments behind [repaidOf]
  /// without a screen reaching for a repository itself — the same
  /// arrangement `BudgetProvider` uses for its transaction queries.
  final TransactionRepository _transactionRepo;

  static const _uuid = Uuid();

  DebtProvider({DebtRepository? repository, TransactionRepository? transactionRepository})
      : _repository = repository ?? DebtRepository(),
        _transactionRepo = transactionRepository ?? TransactionRepository();

  List<DebtModel> _debts = [];
  Map<String, double> _repaid = {};
  bool _isLoading = false;
  String? _error;

  List<DebtModel> get debts => _debts;
  List<DebtModel> get activeDebts => _debts.where((d) => !d.isArchived).toList();

  /// Debts that were archived rather than deleted because they still had
  /// repayments. Surfaced so the archive is somewhere the user can reach —
  /// an archived debt used to vanish from every screen, which made the
  /// promise that "your history stays intact" impossible to verify.
  List<DebtModel> get archivedDebts => _debts.where((d) => d.isArchived).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  double repaidOf(String debtId) => _repaid[debtId] ?? 0;

  double outstandingOf(DebtModel debt) {
    final remaining = debt.principal - repaidOf(debt.id);
    return remaining < 0 ? 0 : remaining;
  }

  bool isSettled(DebtModel debt) => outstandingOf(debt) <= 0;

  /// Sum of what's still owed *to you* across every active 'lent' debt.
  double get totalOwedToMe => activeDebts
      .where((d) => d.isLent)
      .fold(0.0, (sum, d) => sum + outstandingOf(d));

  /// Sum of what *you* still owe across every active 'borrowed' debt.
  double get totalIOwe => activeDebts
      .where((d) => d.isBorrowed)
      .fold(0.0, (sum, d) => sum + outstandingOf(d));

  Future<void> loadDebts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _debts = await _repository.getAll();
      _repaid = await _repository.getAllRepaid();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Every repayment tagged with this debt, newest first — the rows that add
  /// up to [repaidOf].
  Future<List<TransactionModel>> transactionsFor(String debtId) =>
      _transactionRepo.getByDebtId(debtId);

  DebtModel? getDebtById(String id) {
    try {
      return _debts.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<DebtModel> addDebt({
    required String name,
    required String type,
    required double principal,
    DateTime? dueDate,
    double? interestRate,
    String? note,
  }) async {
    final debt = DebtModel(
      id: _uuid.v4(),
      name: name,
      type: type,
      principal: principal,
      dueDate: dueDate,
      interestRate: interestRate,
      note: note,
      createdAt: DateTime.now(),
    );
    await _repository.insert(debt);
    await loadDebts();
    return debt;
  }

  Future<void> updateDebt(DebtModel debt) async {
    await _repository.update(debt);
    await loadDebts();
  }

  Future<int> countUsage(String id) => _repository.countUsage(id);

  /// Remove a debt.
  ///
  /// By default a debt with repayments is archived rather than deleted: the
  /// repayments were real money movements, and dropping them would leave
  /// every past account balance wrong.
  ///
  /// [deleteRepayments] is the explicit opt-out for a debt created by
  /// mistake. It removes the tagged transactions too, so callers must reload
  /// the providers that derive from them (accounts, budgets, analytics,
  /// transactions).
  Future<void> deleteDebt(String id, {bool deleteRepayments = false}) async {
    if (deleteRepayments) {
      await _repository.deleteWithTransactions(id);
      await loadDebts();
      return;
    }
    final usage = await _repository.countUsage(id);
    if (usage > 0) {
      await _repository.archive(id);
    } else {
      await _repository.deleteUnused(id);
    }
    await loadDebts();
  }

  Future<void> unarchiveDebt(String id) async {
    await _repository.unarchive(id);
    await loadDebts();
  }
}
