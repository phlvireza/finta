import 'package:intl/intl.dart';

/// Date utilities for grouping and relative labels.
class AppDateUtils {
  AppDateUtils._();

  /// Returns a human-friendly date label: "Today", "Yesterday", or "Jul 20".
  static String relativeLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    final diff = today.difference(dateOnly).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date); // e.g. "Wednesday"
    if (date.year == now.year) return DateFormat('MMM d').format(date); // e.g. "Jul 20"
    return DateFormat('MMM d, yyyy').format(date); // e.g. "Jul 20, 2025"
  }

  /// Format a date as "Jul 25, 2026".
  static String formatFull(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Format a date as "July 2026".
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  /// Format a date as "2026-07-25" (ISO date only).
  static String formatIso(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Fraction (0.0–1.0) of [period] that has elapsed as of today. Used to
  /// give a budget's progress bar a pace reference — "85% used" means
  /// something very different on day 3 of a period than on day 27.
  static double periodElapsedFraction(({DateTime start, DateTime end}) period) {
    final today = DateTime.now();
    final totalDays = period.end.difference(period.start).inDays + 1;
    final elapsedDays =
        DateTime(today.year, today.month, today.day).difference(period.start).inDays + 1;
    if (totalDays <= 0) return 1.0;
    return (elapsedDays / totalDays).clamp(0.0, 1.0);
  }

  /// Format a date range for display, omitting the year when both ends
  /// fall in the current year (e.g. "Jul 25 – Aug 24") and including it
  /// otherwise so a year-boundary period stays unambiguous.
  static String formatPeriodRange(DateTime start, DateTime end) {
    final currentYear = DateTime.now().year;
    if (start.year == currentYear && end.year == currentYear) {
      return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}';
    }
    return '${formatFull(start)} – ${formatFull(end)}';
  }

  /// The [day]-th of [year]/[month], clamped to that month's last day.
  /// `DateTime` already rolls month values outside 1–12 into the right
  /// year (month 0 = December of the previous year), so only the day
  /// needs explicit clamping — otherwise e.g. payday 31 in February would
  /// silently overflow into March.
  static DateTime _anchor(int year, int month, int day) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDayOfMonth));
  }

  /// Get the start and end dates of the current budget period based on
  /// the user's payday. [referenceDate] defaults to now; tests pass a
  /// fixed date to make period boundaries deterministic.
  static ({DateTime start, DateTime end}) getCurrentPeriod(
    int payday, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final thisMonthAnchor = _anchor(today.year, today.month, payday);
    final periodStart = today.isBefore(thisMonthAnchor)
        ? _anchor(today.year, today.month - 1, payday)
        : thisMonthAnchor;

    // End is always the day before the NEXT anchor — guarantees
    // contiguous, non-overlapping periods for every payday value.
    final periodEnd = _anchor(periodStart.year, periodStart.month + 1, payday)
        .subtract(const Duration(days: 1));

    return (start: periodStart, end: periodEnd);
  }

  static ({DateTime start, DateTime end}) getWeeklyPeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Assuming week starts on Monday
    final start = today.subtract(Duration(days: today.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return (start: start, end: end);
  }

  static ({DateTime start, DateTime end}) getBiweeklyPeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (today.day <= 15) {
      return (
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month, 15)
      );
    } else {
      return (
        start: DateTime(now.year, now.month, 16),
        end: DateTime(now.year, now.month + 1, 0)
      );
    }
  }

  static ({DateTime start, DateTime end}) getQuarterlyPeriod({DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    final start = DateTime(now.year, quarterStartMonth, 1);
    final end = DateTime(now.year, quarterStartMonth + 3, 0);
    return (start: start, end: end);
  }

  static ({DateTime start, DateTime end}) getYearlyPeriod({DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    return (start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31));
  }

  /// Dispatches to the right "current period" function for a budget's
  /// [periodType] ('weekly'|'monthly'|'quarterly'|'yearly'). Monthly is
  /// the only one anchored to [payday] — the others use calendar
  /// boundaries, since payday-anchoring is specifically a paycheck-cycle
  /// concept.
  static ({DateTime start, DateTime end}) getCurrentPeriodFor(String periodType, int payday) {
    switch (periodType) {
      case 'weekly':
        return getWeeklyPeriod();
      case 'quarterly':
        return getQuarterlyPeriod();
      case 'yearly':
        return getYearlyPeriod();
      case 'monthly':
      default:
        return getCurrentPeriod(payday);
    }
  }

  /// Steps [current] back one period for the given [periodType] — the
  /// budget-period counterpart to [getPreviousPeriod], which only knows
  /// about the fixed payday-anchored monthly period.
  static ({DateTime start, DateTime end}) getPreviousPeriodFor(
    String periodType,
    ({DateTime start, DateTime end}) current,
    int payday,
  ) {
    switch (periodType) {
      case 'weekly':
        return (
          start: current.start.subtract(const Duration(days: 7)),
          end: current.end.subtract(const Duration(days: 7)),
        );
      case 'quarterly':
        final start = DateTime(current.start.year, current.start.month - 3, 1);
        final end = DateTime(start.year, start.month + 3, 0);
        return (start: start, end: end);
      case 'yearly':
        return (
          start: DateTime(current.start.year - 1, 1, 1),
          end: DateTime(current.start.year - 1, 12, 31),
        );
      case 'monthly':
      default:
        return getPreviousPeriod(current);
    }
  }

  static ({DateTime start, DateTime end}) getPreviousPeriod(({DateTime start, DateTime end}) current) {
    // Inclusive day count: a payday-anchored monthly period is always
    // 28 (Feb, non-leap) to 31 days long. Weekly (7) and biweekly (13-16)
    // never land in this range, so this reliably tells them apart.
    final dayCount = current.end.difference(current.start).inDays + 1;

    if (dayCount >= 28 && dayCount <= 31) {
      // Monthly: step back one calendar month from the anchor day, then
      // re-derive the end the same way getCurrentPeriod does, so a short
      // month (e.g. stepping from Mar 31 back to Feb) doesn't drift the
      // anchor day permanently.
      final anchorDay = current.start.day;
      final prevStart = _anchor(current.start.year, current.start.month - 1, anchorDay);
      final prevEnd = _anchor(prevStart.year, prevStart.month + 1, anchorDay)
          .subtract(const Duration(days: 1));
      return (start: prevStart, end: prevEnd);
    }

    final duration = current.end.difference(current.start);
    final prevEnd = current.start.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(duration);
    return (start: prevStart, end: prevEnd);
  }

  /// Group a list of dates by their relative label.
  static Map<String, List<T>> groupByDate<T>(
    List<T> items,
    DateTime Function(T) dateExtractor,
  ) {
    final groups = <String, List<T>>{};
    for (final item in items) {
      final label = relativeLabel(dateExtractor(item));
      groups.putIfAbsent(label, () => []).add(item);
    }
    return groups;
  }

  /// Get the month name from a month number (1-12).
  static String monthName(int month) {
    return DateFormat('MMMM').format(DateTime(2026, month));
  }

  /// Get short month name from a month number (1-12).
  static String monthShort(int month) {
    return DateFormat('MMM').format(DateTime(2026, month));
  }
}
