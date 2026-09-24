import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/date_utils.dart';
import 'package:finta/models/transaction_model.dart';
import 'package:finta/providers/transaction_provider.dart';
import 'package:finta/repositories/transaction_repository.dart';

class _Ledger extends TransactionRepository {
  final rows = <TransactionModel>[];

  @override
  Future<List<TransactionModel>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async => rows
      .where((row) => !row.date.isBefore(start) && !row.date.isAfter(end))
      .toList();

  @override
  Future<bool> hasAnyNonTransferTransaction() async => rows.isNotEmpty;

  @override
  Future<double> getSumByTypeAndDateRange(
    String type,
    DateTime start,
    DateTime end,
  ) async => rows
      .where(
        (row) =>
            row.type == type &&
            !row.isTransfer &&
            !row.date.isBefore(start) &&
            !row.date.isAfter(end),
      )
      .fold<double>(0.0, (sum, row) => sum + row.amount);
}

TransactionModel _expense(String id, double amount, DateTime date) =>
    TransactionModel(
      id: id,
      type: 'expense',
      amount: amount,
      categoryId: 'food',
      accountId: 'cash',
      date: date,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  test(
    'current expense comparison excludes future entries but keeps cycle total',
    () async {
      final now = DateTime.now();
      final payday = now.day;
      final current = AppDateUtils.getCurrentPeriod(payday);
      final previous = AppDateUtils.getPreviousPeriod(current);
      final beforePrevious = AppDateUtils.getPreviousPeriod(previous);
      final ledger = _Ledger();
      ledger.rows.addAll([
        _expense('today', 40, current.start),
        _expense(
          'future',
          60,
          DateTime(
            current.start.year,
            current.start.month,
            current.start.day + 1,
          ),
        ),
        _expense('previous-first', 20, previous.start),
        _expense(
          'previous-later',
          30,
          DateTime(
            previous.start.year,
            previous.start.month,
            previous.start.day + 1,
          ),
        ),
        _expense('earlier', 5, beforePrevious.start),
      ]);
      final provider = TransactionProvider(repository: ledger);
      addTearDown(provider.dispose);

      await provider.loadTransactions(payday: payday);
      expect(provider.totalExpense, 100);
      expect(provider.comparableExpense, 40);
      expect(provider.previousTotalExpense, 50);
      expect(provider.previousComparableExpense, 20);

      await provider.goToPreviousPeriod(payday: payday);
      expect(provider.totalExpense, 50);
      expect(provider.comparableExpense, 50);
      expect(provider.previousComparableExpense, 5);
    },
  );
}
