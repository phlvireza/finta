import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

  // How the Period Recap pages forward. There is no getNextPeriod:
  // re-anchoring on the day after a period ends is the next one by
  // definition, given getCurrentPeriod's contiguity guarantee above.
  group('paging forward a period', () {
    ({DateTime start, DateTime end}) next(
      ({DateTime start, DateTime end}) period,
      int payday,
    ) {
      return AppDateUtils.getCurrentPeriod(
        payday,
        referenceDate: period.end.add(const Duration(days: 1)),
      );
    }

    test('inverts getPreviousPeriod for a payday-21 cycle', () {
      final current = AppDateUtils.getCurrentPeriod(
        21,
        referenceDate: DateTime(2026, 8, 6),
      );
      expect(current.start, DateTime(2026, 7, 21));
      expect(current.end, DateTime(2026, 8, 20));

      final previous = AppDateUtils.getPreviousPeriod(current);
      final backAgain = next(previous, 21);
      expect(backAgain.start, current.start);
      expect(backAgain.end, current.end);
    });

    test('round-trips across month-length edges', () {
      // Jan→Feb, Feb→Mar and Dec→Jan are where day clamping and the year
      // rollover bite.
      final references = [
        DateTime(2026, 1, 25),
        DateTime(2026, 2, 25),
        DateTime(2026, 12, 25),
      ];
      for (final payday in [1, 21, 28, 29, 30, 31]) {
        for (final reference in references) {
          final current = AppDateUtils.getCurrentPeriod(payday, referenceDate: reference);
          final previous = AppDateUtils.getPreviousPeriod(current);
          final forward = next(previous, payday);
          expect(
            forward.start,
            current.start,
            reason: 'payday $payday from $reference',
          );
          expect(forward.end, current.end, reason: 'payday $payday from $reference');
        }
      }
    });

    test('lands on the period that directly abuts the one before it', () {
      var period = AppDateUtils.getCurrentPeriod(21, referenceDate: DateTime(2026, 1, 5));
      for (var step = 0; step < 24; step++) {
        final forward = next(period, 21);
        expect(
          forward.start,
          period.end.add(const Duration(days: 1)),
          reason: 'step $step',
        );
        period = forward;
      }
    });
  });

  // One-off budgets resolve their range from their own createdAt, so every
  // period type has to answer "which period contains this date?" — not just
  // "which period is it now?".
  group('referenceDate support', () {
    test('getWeeklyPeriod returns the Monday–Sunday week containing the date', () {
      // 2026-08-05 is a Wednesday.
      final period = AppDateUtils.getWeeklyPeriod(
        referenceDate: DateTime(2026, 8, 5),
      );
      expect(period.start, DateTime(2026, 8, 3));
      expect(period.end, DateTime(2026, 8, 9));
    });

    test('getWeeklyPeriod handles a date that is already Monday', () {
      final period = AppDateUtils.getWeeklyPeriod(
        referenceDate: DateTime(2026, 8, 3),
      );
      expect(period.start, DateTime(2026, 8, 3));
      expect(period.end, DateTime(2026, 8, 9));
    });

    test('getWeeklyPeriod crosses a month boundary without clamping', () {
      // 2026-08-01 is a Saturday, so its week starts back in July.
      final period = AppDateUtils.getWeeklyPeriod(
        referenceDate: DateTime(2026, 8, 1),
      );
      expect(period.start, DateTime(2026, 7, 27));
      expect(period.end, DateTime(2026, 8, 2));
    });

    test('getBiweeklyPeriod splits the month at the 15th', () {
      expect(
        AppDateUtils.getBiweeklyPeriod(referenceDate: DateTime(2026, 8, 15)),
        (start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 15)),
      );
      expect(
        AppDateUtils.getBiweeklyPeriod(referenceDate: DateTime(2026, 8, 16)),
        (start: DateTime(2026, 8, 16), end: DateTime(2026, 8, 31)),
      );
    });

    test('getBiweeklyPeriod ends the second half on a short month', () {
      // February 2026 has 28 days — the second half must not run to the 31st.
      final period = AppDateUtils.getBiweeklyPeriod(
        referenceDate: DateTime(2026, 2, 20),
      );
      expect(period.start, DateTime(2026, 2, 16));
      expect(period.end, DateTime(2026, 2, 28));
    });

    test('getCurrentPeriodFor threads referenceDate to both period types', () {
      // Budgets offer weekly and monthly only.
      final reference = DateTime(2026, 8, 5);

      expect(
        AppDateUtils.getCurrentPeriodFor('weekly', 25, referenceDate: reference),
        (start: DateTime(2026, 8, 3), end: DateTime(2026, 8, 9)),
      );
      // Monthly is the payday-anchored one: Aug 5 with payday 25 sits in
      // the cycle that opened on Jul 25.
      expect(
        AppDateUtils.getCurrentPeriodFor('monthly', 25, referenceDate: reference),
        (start: DateTime(2026, 7, 25), end: DateTime(2026, 8, 24)),
      );
    });

    test('an unknown period type falls back to the monthly cycle', () {
      // Covers a row written by an older build, or a typo'd period string —
      // it degrades to the app's default cycle rather than throwing.
      expect(
        AppDateUtils.getCurrentPeriodFor('fortnightly', 25,
            referenceDate: DateTime(2026, 8, 5)),
        (start: DateTime(2026, 7, 25), end: DateTime(2026, 8, 24)),
      );
    });
  });

  group('relativeLabel', () {
    // "Today" and "Yesterday" are relative to the wall clock by nature, so
    // these two derive their input from now rather than a literal. Every
    // other branch below uses fixed dates.
    DateTime dayOffset(int days) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    }

    test('uses the caller-supplied word for today', () {
      expect(
        AppDateUtils.relativeLabel(dayOffset(0),
            todayLabel: 'Hari ini', yesterdayLabel: 'Kemarin'),
        'Hari ini',
      );
    });

    test('uses the caller-supplied word for yesterday', () {
      expect(
        AppDateUtils.relativeLabel(dayOffset(1),
            todayLabel: 'Hari ini', yesterdayLabel: 'Kemarin'),
        'Kemarin',
      );
    });

    test('falls through to a formatted date once the day is old enough', () {
      final label = AppDateUtils.relativeLabel(dayOffset(30),
          todayLabel: 'Hari ini', yesterdayLabel: 'Kemarin');
      expect(label, isNot('Hari ini'));
      expect(label, isNot('Kemarin'));
      expect(label, isNotEmpty);
    });
  });

  group('groupByDate', () {
    test('groups timestamps that share a calendar day', () {
      final items = [
        DateTime(2026, 8, 18, 9, 30),
        DateTime(2026, 8, 18, 21, 5),
        DateTime(2026, 8, 17, 12, 0),
      ];

      final grouped = AppDateUtils.groupByDate(items, (d) => d);

      expect(grouped.keys, hasLength(2));
      expect(grouped[DateTime(2026, 8, 18)], hasLength(2));
      expect(grouped[DateTime(2026, 8, 17)], hasLength(1));
    });

    test('keys are stripped to midnight so the time of day never splits a group', () {
      final grouped = AppDateUtils.groupByDate(
        [DateTime(2026, 8, 18, 23, 59, 59)],
        (d) => d,
      );

      expect(grouped.keys.single, DateTime(2026, 8, 18));
    });

    // The list screens render groups in map order, so a sorted input has to
    // stay sorted on the way through.
    test('preserves the order days first appear in', () {
      final items = [
        DateTime(2026, 8, 18),
        DateTime(2026, 8, 17),
        DateTime(2026, 8, 18),
        DateTime(2026, 8, 15),
      ];

      final grouped = AppDateUtils.groupByDate(items, (d) => d);

      expect(grouped.keys.toList(), [
        DateTime(2026, 8, 18),
        DateTime(2026, 8, 17),
        DateTime(2026, 8, 15),
      ]);
    });

    test('returns an empty map for no items', () {
      expect(AppDateUtils.groupByDate(<DateTime>[], (d) => d), isEmpty);
    });
  });

  group('formatIso', () {
    // Keys the heatmap's per-day lookup and names exported files, so it must
    // not follow the UI language the way the display formatters do.
    test('is stable regardless of the app locale', () {
      Intl.defaultLocale = 'id';
      addTearDown(() => Intl.defaultLocale = null);

      expect(AppDateUtils.formatIso(DateTime(2026, 8, 18)), '2026-08-18');
    });
  });
}
