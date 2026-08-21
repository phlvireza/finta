import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/budget_leftover.dart';

void main() {
  final resolved = DateTime(2026, 8, 25, 9, 30);

  group('computeBudgetLeftover', () {
    test('returns the unspent portion of the budget', () {
      expect(computeBudgetLeftover(amount: 500, spent: 300), 200);
    });

    test('returns zero when the budget was spent exactly', () {
      expect(computeBudgetLeftover(amount: 500, spent: 500), 0);
    });

    test('clamps an overspent budget to zero rather than going negative', () {
      // A negative leftover would roll forward as a penalty the user never
      // agreed to — overspend is the rollover system's business.
      expect(computeBudgetLeftover(amount: 500, spent: 720), 0);
    });

    test('returns the whole budget when nothing was spent', () {
      expect(computeBudgetLeftover(amount: 500, spent: 0), 500);
    });
  });

  group('needsLeftoverPrompt', () {
    test('prompts for an ended one-off budget with money left', () {
      expect(
        needsLeftoverPrompt(
          isActive: false,
          isRecurring: false,
          leftoverResolvedAt: null,
          leftover: 200,
        ),
        isTrue,
      );
    });

    test('does not prompt while the budget is still active', () {
      // Mid-period, "leftover" is just money not spent yet.
      expect(
        needsLeftoverPrompt(
          isActive: true,
          isRecurring: false,
          leftoverResolvedAt: null,
          leftover: 200,
        ),
        isFalse,
      );
    });

    test('never prompts for a recurring budget', () {
      // rolloverMode already answers this question every period.
      expect(
        needsLeftoverPrompt(
          isActive: false,
          isRecurring: true,
          leftoverResolvedAt: null,
          leftover: 200,
        ),
        isFalse,
      );
    });

    test('does not prompt once the user has answered', () {
      expect(
        needsLeftoverPrompt(
          isActive: false,
          isRecurring: false,
          leftoverResolvedAt: resolved,
          leftover: 200,
        ),
        isFalse,
      );
    });

    test('does not prompt when there is nothing left over', () {
      expect(
        needsLeftoverPrompt(
          isActive: false,
          isRecurring: false,
          leftoverResolvedAt: null,
          leftover: 0,
        ),
        isFalse,
      );
    });
  });

  group('rollForwardAmount', () {
    test('adds the leftover on top of the original limit', () {
      // 500 that spent 300 rolls forward as 700, not 200 — the original
      // limit is what the category needs in a normal period.
      expect(rollForwardAmount(budgetAmount: 500, leftover: 200), 700);
    });

    test('leaves the limit untouched when nothing was left over', () {
      expect(rollForwardAmount(budgetAmount: 500, leftover: 0), 500);
    });
  });
}
