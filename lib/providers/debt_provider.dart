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

  /// Remove a debt. If any transaction still references it, it's archived
  /// instead so those repayments keep a resolvable debt name.
  Future<void> deleteDebt(String id) async {
    final usage = await _repository.countUsage(id);
    if (usage > 0) {
      await _repository.archive(id);
    } else {
      await _repository.deleteUnused(id);
    }
    await loadDebts();
  }
}
