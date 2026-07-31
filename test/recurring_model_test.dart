import 'package:flutter_test/flutter_test.dart';
import 'package:finta/models/recurring_transaction_model.dart';

RecurringTransactionModel _template({
  required String frequency,
  required DateTime startDate,
  DateTime? lastRunDate,
  DateTime? endDate,
}) {
  return RecurringTransactionModel(
    id: 'r1',
    type: 'expense',
    amount: 100000,
    categoryId: 'c1',
    frequency: frequency,
    startDate: startDate,
    lastRunDate: lastRunDate,
    endDate: endDate,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('nextOccurrence', () {
    test('the first occurrence is always startDate itself, for every frequency', () {
      for (final frequency in ['daily', 'weekly', 'biweekly', 'monthly', 'yearly']) {
        final startDate = DateTime(2026, 7, 15);
        final template = _template(frequency: frequency, startDate: startDate);
        expect(
          template.nextOccurrence,
          startDate,
          reason: '$frequency should post its first occurrence on startDate',
        );
      }
    });

    test('after a run, nextOccurrence advances from lastRunDate', () {
      final template = _template(
        frequency: 'weekly',
        startDate: DateTime(2026, 7, 1),
        lastRunDate: DateTime(2026, 7, 15),
      );
      expect(template.nextOccurrence, DateTime(2026, 7, 22));
    });
  });

  group('advanceFrom — monthly anchoring', () {
    test('a template anchored on the 31st clamps through February without drifting', () {
      final template = _template(
        frequency: 'monthly',
        startDate: DateTime(2026, 1, 31),
      );

      // Jan 31 -> Feb 28 (2026 is not a leap year) -> Mar 31 (recovers the
      // anchor day instead of permanently drifting to Mar 3, as advancing
      // from the previous *generated* date rather than the anchor would).
      final feb = template.advanceFrom(DateTime(2026, 1, 31));
      expect(feb, DateTime(2026, 2, 28));

      final mar = template.advanceFrom(feb);
      expect(mar, DateTime(2026, 3, 31));

      final apr = template.advanceFrom(mar);
      expect(apr, DateTime(2026, 4, 30));
    });

    test('yearly anchoring clamps Feb 29 in non-leap years and recovers', () {
      final template = _template(
        frequency: 'yearly',
        startDate: DateTime(2024, 2, 29), // 2024 is a leap year
      );

      final y2025 = template.advanceFrom(DateTime(2024, 2, 29));
      expect(y2025, DateTime(2025, 2, 28));

      final y2028 = template.advanceFrom(DateTime(2027, 2, 28));
      expect(y2028, DateTime(2028, 2, 29)); // 2028 is a leap year again
    });
  });

  group('advanceFrom — fixed-interval frequencies', () {
    test('daily/weekly/biweekly advance by a fixed number of days', () {
      final daily = _template(frequency: 'daily', startDate: DateTime(2026, 7, 1));
      expect(daily.advanceFrom(DateTime(2026, 7, 15)), DateTime(2026, 7, 16));

      final weekly = _template(frequency: 'weekly', startDate: DateTime(2026, 7, 1));
      expect(weekly.advanceFrom(DateTime(2026, 7, 15)), DateTime(2026, 7, 22));

      final biweekly = _template(frequency: 'biweekly', startDate: DateTime(2026, 7, 1));
      expect(biweekly.advanceFrom(DateTime(2026, 7, 15)), DateTime(2026, 7, 29));
    });
  });
}
