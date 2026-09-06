import 'package:flutter_test/flutter_test.dart';
import 'package:finta/models/transaction_model.dart';
import 'package:finta/providers/transaction_provider.dart';
import 'package:finta/repositories/transaction_repository.dart';

class _Ledger extends TransactionRepository {
  final List<TransactionModel> rows = [];

  @override
  Future<List<TransactionModel>> getAll() async => List.of(rows);
  @override
  Future<List<TransactionModel>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => rows
      .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end))
      .toList();
  @override
  Future<bool> hasAnyNonTransferTransaction() async =>
      rows.any((t) => !t.isTransfer);
  @override
  Future<double> getSumByTypeAndDateRange(
    String type,
    DateTime start,
    DateTime end,
  ) async => 0;
  @override
  Future<TransactionModel?> getById(String id) async =>
      rows.where((t) => t.id == id).firstOrNull;
  @override
  Future<void> deleteTransferPair(String transferId) async =>
      rows.removeWhere((t) => t.transferId == transferId);
}

void main() {
  for (final loadHistory in [false, true]) {
    test(
      'deleting a transfer clears period rows with history loaded=$loadHistory',
      () async {
        final repo = _Ledger();
        final now = DateTime.now();
        final date = DateTime(now.year, now.month, now.day);
        for (final type in ['income', 'expense']) {
          repo.rows.add(
            TransactionModel(
              id: type,
              type: type,
              amount: 100,
              categoryId: 'transfer',
              accountId: type,
              date: date,
              createdAt: date,
              updatedAt: date,
              isTransfer: true,
              transferId: 'pair',
            ),
          );
        }
        final provider = TransactionProvider(repository: repo);
        addTearDown(provider.dispose);
        await provider.loadTransactions(payday: 1);
        if (loadHistory) await provider.loadAllTransactions();
        expect(provider.transactions, hasLength(2));
        await provider.deleteTransaction('expense');
        expect(repo.rows, isEmpty);
        expect(provider.transactions, isEmpty);
        expect(provider.allTransactions, isEmpty);
        expect(provider.totalExpense, 0);
        expect(provider.totalIncome, 0);
      },
    );
  }
}
