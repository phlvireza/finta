import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/subscription_detector.dart';
import 'package:finta/models/transaction_model.dart';

TransactionModel _tx({
  required String merchant,
  required double amount,
  required DateTime date,
  String type = 'expense',
  bool isTransfer = false,
}) {
  return TransactionModel(
    id: '$merchant-${date.toIso8601String()}',
    type: type,
    amount: amount,
    categoryId: 'cat1',
    accountId: 'acc1',
    merchant: merchant,
    isTransfer: isTransfer,
    date: date,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('detectSubscriptionCandidates', () {
    test('flags a merchant charged the same amount roughly every 30 days', () {
      final transactions = [
        _tx(merchant: 'Netflix', amount: 54000, date: DateTime(2026, 4, 15)),
        _tx(merchant: 'Netflix', amount: 54000, date: DateTime(2026, 5, 15)),
        _tx(merchant: 'Netflix', amount: 54000, date: DateTime(2026, 6, 14)),
        _tx(merchant: 'Netflix', amount: 54000, date: DateTime(2026, 7, 15)),
      ];
      final candidates = detectSubscriptionCandidates(transactions);
      expect(candidates, hasLength(1));
      expect(candidates.single.merchant, 'Netflix');
      expect(candidates.single.amount, 54000);
      expect(candidates.single.occurrenceCount, 4);
    });

    test('requires at least the minimum occurrence count', () {
      final transactions = [
        _tx(merchant: 'Netflix', amount: 54000, date: DateTime(2026, 6, 15)),
        _tx(merchant: 'Netflix', amount: 54000, date: DateTime(2026, 7, 15)),
      ];
      expect(detectSubscriptionCandidates(transactions), isEmpty);
    });

    test('rejects irregular spacing (not subscription-like)', () {
      final transactions = [
        _tx(merchant: 'Grocery Mart', amount: 200000, date: DateTime(2026, 5, 1)),
        _tx(merchant: 'Grocery Mart', amount: 210000, date: DateTime(2026, 5, 8)),
        _tx(merchant: 'Grocery Mart', amount: 195000, date: DateTime(2026, 6, 2)),
      ];
      expect(detectSubscriptionCandidates(transactions), isEmpty);
    });

    test('rejects amounts that vary too much to be a fixed subscription fee', () {
      final transactions = [
        _tx(merchant: 'Utility Co', amount: 50000, date: DateTime(2026, 4, 15)),
        _tx(merchant: 'Utility Co', amount: 120000, date: DateTime(2026, 5, 15)),
        _tx(merchant: 'Utility Co', amount: 80000, date: DateTime(2026, 6, 15)),
      ];
      expect(detectSubscriptionCandidates(transactions), isEmpty);
    });

    test('ignores transfers and income even with a regular pattern', () {
      final transactions = [
        _tx(merchant: 'Own Savings', amount: 500000, date: DateTime(2026, 4, 15), isTransfer: true),
        _tx(merchant: 'Own Savings', amount: 500000, date: DateTime(2026, 5, 15), isTransfer: true),
        _tx(merchant: 'Own Savings', amount: 500000, date: DateTime(2026, 6, 15), isTransfer: true),
        _tx(merchant: 'Employer', amount: 5000000, date: DateTime(2026, 4, 25), type: 'income'),
        _tx(merchant: 'Employer', amount: 5000000, date: DateTime(2026, 5, 25), type: 'income'),
        _tx(merchant: 'Employer', amount: 5000000, date: DateTime(2026, 6, 25), type: 'income'),
      ];
      expect(detectSubscriptionCandidates(transactions), isEmpty);
    });

    test('excludes merchants already tracked as a recurring template', () {
      final transactions = [
        _tx(merchant: 'Spotify', amount: 55000, date: DateTime(2026, 4, 15)),
        _tx(merchant: 'Spotify', amount: 55000, date: DateTime(2026, 5, 15)),
        _tx(merchant: 'Spotify', amount: 55000, date: DateTime(2026, 6, 15)),
      ];
      final candidates = detectSubscriptionCandidates(
        transactions,
        excludeMerchants: {'spotify'},
      );
      expect(candidates, isEmpty, reason: 'exclusion should be case-insensitive');
    });

    test('folds spellings that differ only by case or spacing into one merchant', () {
      // Typed slightly differently each month. Grouped on the raw string these
      // are three merchants with one charge each, all below minOccurrences,
      // and the subscription is never flagged.
      final transactions = [
        _tx(merchant: 'Netflix', amount: 54000, date: DateTime(2026, 4, 15)),
        _tx(merchant: 'netflix', amount: 54000, date: DateTime(2026, 5, 15)),
        _tx(merchant: ' NETFLIX ', amount: 54000, date: DateTime(2026, 6, 14)),
      ];
      final candidates = detectSubscriptionCandidates(transactions);

      expect(candidates, hasLength(1));
      expect(candidates.single.occurrenceCount, 3);
    });

    test('reports the most recent spelling, not the normalized key', () {
      final transactions = [
        _tx(merchant: 'netflix', amount: 54000, date: DateTime(2026, 4, 15)),
        _tx(merchant: 'netflix', amount: 54000, date: DateTime(2026, 5, 15)),
        _tx(merchant: 'Netflix', amount: 54000, date: DateTime(2026, 6, 14)),
      ];
      final candidate = detectSubscriptionCandidates(transactions).single;

      expect(candidate.merchant, 'Netflix');
    });

    test('exclusion matches across spelling variants too', () {
      final transactions = [
        _tx(merchant: 'Spotify', amount: 55000, date: DateTime(2026, 4, 15)),
        _tx(merchant: 'spotify ', amount: 55000, date: DateTime(2026, 5, 15)),
        _tx(merchant: 'SPOTIFY', amount: 55000, date: DateTime(2026, 6, 15)),
      ];
      final candidates = detectSubscriptionCandidates(
        transactions,
        excludeMerchants: {'  Spotify  '},
      );

      expect(candidates, isEmpty);
    });

    test('predicts the next date from the average spacing of recent charges', () {
      final transactions = [
        _tx(merchant: 'Gym', amount: 300000, date: DateTime(2026, 4, 1)),
        _tx(merchant: 'Gym', amount: 300000, date: DateTime(2026, 5, 1)),
        _tx(merchant: 'Gym', amount: 300000, date: DateTime(2026, 6, 1)),
      ];
      final candidate = detectSubscriptionCandidates(transactions).single;
      expect(candidate.lastDate, DateTime(2026, 6, 1));
      // Average spacing here is 30.5 days (30 then 31), rounds to 31.
      expect(candidate.predictedNextDate, DateTime(2026, 6, 1).add(const Duration(days: 31)));
    });
  });
}
