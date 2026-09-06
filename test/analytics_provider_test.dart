import 'package:finta/providers/analytics_provider.dart';
import 'package:finta/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _AnalyticsRepository extends TransactionRepository {
  final categories = <String, List<Map<String, dynamic>>>{};
  final totals = <String, double>{};
  final previousTotals = <String, double>{};
  DateTime? previousStart;
  Object? incomeError;

  @override
  Future<List<Map<String, dynamic>>> getCategorySums(
    String type,
    DateTime start,
    DateTime end,
  ) async {
    if (type == 'income' && incomeError != null) throw incomeError!;
    return categories[type] ?? [];
  }

  @override
  Future<double> getSumByTypeAndDateRange(
    String type,
    DateTime start,
    DateTime end,
  ) async => (start == previousStart ? previousTotals : totals)[type] ?? 0;
}

void main() {
  final start = DateTime(2026, 8, 1);
  final end = DateTime(2026, 8, 31);
  late _AnalyticsRepository repository;
  late AnalyticsProvider provider;

  setUp(() {
    repository = _AnalyticsRepository();
    provider = AnalyticsProvider(repository: repository);
  });
  tearDown(() => provider.dispose());

  test(
    'breakdowns preserve order and use each ledger total as denominator',
    () async {
      repository.categories.addAll({
        'expense': [
          {'categoryId': 'food', 'total': 30},
          {'categoryId': 'travel', 'total': 12.5},
        ],
        'income': [
          {'categoryId': 'salary', 'total': 150},
          {'categoryId': 'interest', 'total': 2.5},
        ],
      });
      repository.totals.addAll({'expense': 50, 'income': 200});
      final loading = <bool>[];
      provider.addListener(() => loading.add(provider.isLoading));

      await provider.loadAnalytics(start: start, end: end);

      expect(provider.totalExpense, 50);
      expect(provider.totalIncome, 200);
      expect(provider.expenseBreakdown.map((c) => c.categoryId), [
        'food',
        'travel',
      ]);
      expect(provider.expenseBreakdown.map((c) => c.total), [30.0, 12.5]);
      expect(provider.expenseBreakdown.map((c) => c.percentage), [0.6, 0.25]);
      expect(provider.incomeBreakdown.map((c) => c.categoryId), [
        'salary',
        'interest',
      ]);
      expect(provider.incomeBreakdown.map((c) => c.total), [150.0, 2.5]);
      expect(provider.incomeBreakdown.map((c) => c.percentage), [0.75, 0.0125]);
      expect(provider.rangeStart, start);
      expect(provider.rangeEnd, end);
      expect(provider.error, isNull);
      expect(loading, [true, false]);
    },
  );

  for (final total in [0.0, -10.0]) {
    test('nonpositive ledger total $total produces zero percentages', () async {
      for (final type in ['income', 'expense']) {
        repository.categories[type] = [
          {'categoryId': type, 'total': 5},
        ];
        repository.totals[type] = total;
      }
      await provider.loadAnalytics(start: start, end: end);
      expect(provider.expenseBreakdown.single.percentage, 0);
      expect(provider.incomeBreakdown.single.percentage, 0);
      expect(provider.expenseBreakdown.single.total, 5);
      expect(provider.incomeBreakdown.single.total, 5);
    });
  }

  test(
    'empty reload clears breakdowns and previous comparison totals',
    () async {
      repository.previousStart = DateTime(2026, 7, 1);
      repository.previousTotals.addAll({'income': 900, 'expense': 300});
      repository.totals.addAll({'income': 100, 'expense': 20});
      for (final type in ['income', 'expense']) {
        repository.categories[type] = [
          {'categoryId': type, 'total': 10},
        ];
      }
      await provider.loadAnalytics(
        start: start,
        end: end,
        comparedTo: (
          start: repository.previousStart!,
          end: DateTime(2026, 7, 31),
        ),
      );
      expect(provider.previousTotalIncome, 900);
      expect(provider.previousTotalExpense, 300);
      repository.categories.clear();
      repository.totals.clear();

      await provider.loadAnalytics(start: start, end: end);

      expect(provider.incomeBreakdown, isEmpty);
      expect(provider.expenseBreakdown, isEmpty);
      expect(provider.totalIncome, 0);
      expect(provider.totalExpense, 0);
      expect(provider.previousTotalIncome, 0);
      expect(provider.previousTotalExpense, 0);
    },
  );

  test(
    'failed income load retains prior income and publishes updated expense',
    () async {
      repository.categories['income'] = [
        {'categoryId': 'salary', 'total': 100},
      ];
      repository.totals['income'] = 100;
      await provider.loadAnalytics(start: start, end: end);
      final failure = StateError('income unavailable');
      repository.incomeError = failure;
      repository.categories['expense'] = [
        {'categoryId': 'food', 'total': 25},
      ];
      repository.totals['expense'] = 50;
      final loading = <bool>[];
      provider.addListener(() => loading.add(provider.isLoading));

      await expectLater(
        provider.loadAnalytics(start: start, end: end),
        throwsA(same(failure)),
      );

      expect(provider.error, failure.toString());
      expect(loading, [true, false]);
      expect(provider.expenseBreakdown.single.percentage, 0.5);
      expect(provider.totalExpense, 50);
      expect(provider.incomeBreakdown.single.total, 100);
      expect(provider.totalIncome, 100);

      repository.incomeError = null;
      await provider.loadAnalytics(start: start, end: end);
      expect(provider.error, isNull);
    },
  );
}
