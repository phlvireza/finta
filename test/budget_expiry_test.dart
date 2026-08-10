import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/budget_expiry.dart';
import 'package:finta/core/utils/date_utils.dart';

void main() {
  // A payday-anchored monthly period: payday 25, so Jul 25 – Aug 24.
  final julyPeriod = (
    start: DateTime(2026, 7, 25),
    end: DateTime(2026, 8, 24),
  );

  group('isBudgetExpired', () {
    test('a recurring budget never expires', () {
      // Years past the period it was created in — still live, because
      // recurring budgets re-derive their range from today.
      expect(
        isBudgetExpired(
          isRecurring: true,
          originPeriod: julyPeriod,
          today: DateTime(2030, 1, 1),
        ),
        isFalse,
      );
    });

    test('a one-off budget is live on the first day of its period', () {
      expect(
        isBudgetExpired(
          isRecurring: false,
          originPeriod: julyPeriod,
          today: DateTime(2026, 7, 25),
        ),
        isFalse,
      );
    });

    test('a one-off budget is still live on the final day of its period', () {
      // The boundary that matters: Aug 24 is the last day the budget
      // covers, so it must not be retired until Aug 25.
      expect(
        isBudgetExpired(
          isRecurring: false,
          originPeriod: julyPeriod,
          today: DateTime(2026, 8, 24),
        ),
        isFalse,
      );
    });

    test('a one-off budget expires the day after its period ends', () {
      expect(
        isBudgetExpired(
          isRecurring: false,
          originPeriod: julyPeriod,
          today: DateTime(2026, 8, 25),
        ),
        isTrue,
      );
    });

    test('a time on the final day does not expire the budget early', () {
      // DateTime.now() carries a time; comparing it raw against a
      // midnight-stamped period end would retire the budget at 00:00:01
      // on its last day — a full period early.
      expect(
        isBudgetExpired(
          isRecurring: false,
          originPeriod: julyPeriod,
          today: DateTime(2026, 8, 24, 23, 59, 59),
        ),
        isFalse,
      );
    });

    test('a budget created in a long-past period is expired', () {
      expect(
        isBudgetExpired(
          isRecurring: false,
          originPeriod: julyPeriod,
          today: DateTime(2027, 3, 1),
        ),
        isTrue,
      );
    });
  });

  group('origin period resolution', () {
    // How BudgetExpiryService and BudgetProvider derive the range: a
    // one-off budget resolves it from its own createdAt, not from today.
    test('a monthly one-off budget is pinned to its creation period', () {
      final createdAt = DateTime(2026, 8, 3, 14, 30);
      final period = AppDateUtils.getCurrentPeriodFor(
        'monthly',
        25,
        referenceDate: createdAt,
      );

      // Created Aug 3 with payday 25 → it belongs to the Jul 25 – Aug 24
      // cycle, not to the one starting Aug 25.
      expect(period.start, DateTime(2026, 7, 25));
      expect(period.end, DateTime(2026, 8, 24));

      expect(
        isBudgetExpired(
          isRecurring: false,
          originPeriod: period,
          today: DateTime(2026, 8, 26),
        ),
        isTrue,
      );
    });

    test('a weekly one-off budget is pinned to its creation week', () {
      // Wed 2026-08-05 → the Mon 3rd – Sun 9th week.
      final period = AppDateUtils.getCurrentPeriodFor(
        'weekly',
        25,
        referenceDate: DateTime(2026, 8, 5),
      );

      expect(period.start, DateTime(2026, 8, 3));
      expect(period.end, DateTime(2026, 8, 9));

      expect(
        isBudgetExpired(
          isRecurring: false,
          originPeriod: period,
          today: DateTime(2026, 8, 9),
        ),
        isFalse,
      );
      expect(
        isBudgetExpired(
          isRecurring: false,
          originPeriod: period,
          today: DateTime(2026, 8, 10),
        ),
        isTrue,
      );
    });
  });
}
