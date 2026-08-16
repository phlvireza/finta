import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/daily_totals.dart';
import 'package:finta/models/transaction_model.dart';

/// Fixed clock values throughout — a heatmap that changes shape depending
/// on when the suite runs is untestable.
final _fixed = DateTime(2026, 3, 14);

TransactionModel _tx({
  required double amount,
  required DateTime date,
  String type = 'expense',
  bool isTransfer = false,
}) {
  return TransactionModel(
    id: 'tx-${date.toIso8601String()}-$amount-$type-$isTransfer',
    type: type,
    amount: amount,
    categoryId: 'cat-1',
    accountId: 'acc-1',
    isTransfer: isTransfer,
    date: date,
    createdAt: _fixed,
    updatedAt: _fixed,
  );
}

void main() {
  group('dailyExpenseTotals', () {
    test('returns an empty map for no transactions', () {
      expect(dailyExpenseTotals([]), isEmpty);
    });

    test('sums several expenses landing on the same day', () {
      final day = DateTime(2026, 3, 10);
      final totals = dailyExpenseTotals([
        _tx(amount: 32000, date: day),
        _tx(amount: 65000, date: day),
        _tx(amount: 3000, date: day),
      ]);

      expect(totals, hasLength(1));
      expect(totals[day], 100000);
    });

    test('keys ignore the time of day so one calendar day is one bucket', () {
      final totals = dailyExpenseTotals([
        _tx(amount: 10, date: DateTime(2026, 3, 10, 8, 30)),
        _tx(amount: 15, date: DateTime(2026, 3, 10, 22, 59)),
      ]);

      expect(totals, hasLength(1));
      expect(totals[DateTime(2026, 3, 10)], 25);
    });

    test('excludes income — a salary is not the heaviest spending day', () {
      final day = DateTime(2026, 3, 10);
      final totals = dailyExpenseTotals([
        _tx(amount: 9500000, date: day, type: 'income'),
        _tx(amount: 40000, date: day),
      ]);

      expect(totals[day], 40000);
    });

    test('excludes transfers — moving your own money was never spending', () {
      final day = DateTime(2026, 3, 10);
      final totals = dailyExpenseTotals([
        _tx(amount: 500000, date: day, isTransfer: true),
        _tx(amount: 40000, date: day),
      ]);

      expect(totals[day], 40000);
    });

    test('a day with only transfers is absent rather than zero', () {
      final day = DateTime(2026, 3, 10);
      final totals = dailyExpenseTotals([
        _tx(amount: 500000, date: day, isTransfer: true),
      ]);

      expect(totals.containsKey(day), isFalse);
    });

    test('separates days', () {
      final totals = dailyExpenseTotals([
        _tx(amount: 10, date: DateTime(2026, 3, 10)),
        _tx(amount: 20, date: DateTime(2026, 3, 11)),
      ]);

      expect(totals[DateTime(2026, 3, 10)], 10);
      expect(totals[DateTime(2026, 3, 11)], 20);
    });
  });

  group('maxDailyTotal', () {
    test('is zero for an empty map, so intensity never divides by zero', () {
      expect(maxDailyTotal({}), 0);
    });

    test('returns the heaviest day', () {
      final totals = dailyExpenseTotals([
        _tx(amount: 10, date: DateTime(2026, 3, 10)),
        _tx(amount: 90, date: DateTime(2026, 3, 11)),
        _tx(amount: 40, date: DateTime(2026, 3, 12)),
      ]);

      expect(maxDailyTotal(totals), 90);
    });
  });
}
