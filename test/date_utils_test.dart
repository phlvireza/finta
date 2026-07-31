import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/date_utils.dart';

void main() {
  group('getCurrentPeriod', () {
    test('is contiguous and non-overlapping for every payday value', () {
      // Sweep a reference date through every month (including Feb) so the
      // day-clamping logic is exercised for both leap and non-leap years.
      for (var month = 1; month <= 12; month++) {
        final reference = DateTime(2026, month, 10);
        for (var payday = 1; payday <= 31; payday++) {
          final period = AppDateUtils.getCurrentPeriod(
            payday,
            referenceDate: reference,
          );

          expect(
            period.end.isAfter(period.start),
            isTrue,
            reason: 'payday $payday, reference $reference',
          );

          final nextPeriod = AppDateUtils.getCurrentPeriod(
            payday,
            referenceDate: period.end.add(const Duration(days: 1)),
          );
          expect(
            nextPeriod.start,
            period.end.add(const Duration(days: 1)),
            reason:
                'period for payday $payday must directly abut the next one '
                '(reference $reference)',
          );
        }
      }
    });

    test('payday 31 in February clamps instead of overflowing into March', () {
      // 2026 is not a leap year — February has 28 days.
      final period = AppDateUtils.getCurrentPeriod(
        31,
        referenceDate: DateTime(2026, 2, 15),
      );
      expect(period.start, DateTime(2026, 1, 31));
      expect(period.end, DateTime(2026, 2, 27));
    });

    test('the period after a clamped Feb starts exactly where it left off', () {
      final period = AppDateUtils.getCurrentPeriod(
        31,
        referenceDate: DateTime(2026, 3, 1),
      );
      expect(period.start, DateTime(2026, 2, 28));
      expect(period.end, DateTime(2026, 3, 30));
    });

    test('every day of the year falls inside exactly the returned period', () {
      for (final payday in [1, 15, 28, 29, 30, 31]) {
        for (var day = 1; day <= 365; day++) {
          final reference = DateTime(2026, 1, 1).add(Duration(days: day));
          final period = AppDateUtils.getCurrentPeriod(
            payday,
            referenceDate: reference,
          );
          expect(
            !reference.isBefore(period.start) && !reference.isAfter(period.end),
            isTrue,
            reason: 'payday $payday, day $reference not inside $period',
          );
        }
      }
    });
  });

  group('getPreviousPeriod', () {
    test('steps back one calendar month for a payday-31 period', () {
      final current = AppDateUtils.getCurrentPeriod(
        31,
        referenceDate: DateTime(2026, 2, 15),
      );
      final previous = AppDateUtils.getPreviousPeriod(current);
      expect(previous.start, DateTime(2025, 12, 31));
      expect(previous.end, DateTime(2026, 1, 30));
    });

    test('previous period always ends the day before the current one starts', () {
      for (final payday in [1, 15, 28, 29, 30, 31]) {
        for (var month = 1; month <= 12; month++) {
          final current = AppDateUtils.getCurrentPeriod(
            payday,
            referenceDate: DateTime(2026, month, 10),
          );
          final previous = AppDateUtils.getPreviousPeriod(current);
          expect(
            previous.end.add(const Duration(days: 1)),
            current.start,
            reason: 'payday $payday, month $month',
          );
        }
      }
    });
  });
}
