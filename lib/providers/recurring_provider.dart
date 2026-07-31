import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction_model.dart';
import '../repositories/recurring_repository.dart';

/// Manages recurring transaction templates — CRUD + state.
class RecurringProvider extends ChangeNotifier {
  final RecurringRepository _repository;
  static const _uuid = Uuid();

  RecurringProvider({RecurringRepository? repository})
      : _repository = repository ?? RecurringRepository();

  List<RecurringTransactionModel> _recurringTransactions = [];
  bool _isLoading = false;
  String? _error;

  List<RecurringTransactionModel> get recurringTransactions =>
      _recurringTransactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<RecurringTransactionModel> get activeRecurring =>
      _recurringTransactions.where((r) => r.isActive).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadRecurringTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recurringTransactions = await _repository.getAll();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<RecurringTransactionModel> addRecurring({
    required String type,
    required double amount,
    required String categoryId,
    String? accountId,
    String? note,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      final recurring = RecurringTransactionModel(
        id: _uuid.v4(),
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        note: note,
        frequency: frequency,
        startDate: startDate,
        endDate: endDate,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _repository.insert(recurring);
      _recurringTransactions.insert(0, recurring);
      notifyListeners();
      return recurring;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateRecurring(RecurringTransactionModel recurring) async {
    try {
      await _repository.update(recurring);
      final index = _recurringTransactions.indexWhere((r) => r.id == recurring.id);
      if (index != -1) {
        _recurringTransactions[index] = recurring;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteRecurring(String id) async {
    try {
      await _repository.delete(id);
      final index = _recurringTransactions.indexWhere((r) => r.id == id);
      if (index != -1) {
        _recurringTransactions[index] =
            _recurringTransactions[index].copyWith(isActive: false);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateLastRunDate(String id, DateTime date) async {
    try {
      await _repository.updateLastRunDate(id, date);
      final index = _recurringTransactions.indexWhere((r) => r.id == id);
      if (index != -1) {
        _recurringTransactions[index] =
            _recurringTransactions[index].copyWith(lastRunDate: date);
      }
    } catch (e) {
      rethrow;
    }
  }
}
