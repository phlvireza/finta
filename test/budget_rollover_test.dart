import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/services/budget_rollover_service.dart';

void main() {
  group('applyRolloverStep', () {
    test('positive mode carries forward an unspent surplus', () {
      final carry = applyRolloverStep(
        previousCarry: 0,
        budgeted: 500000,
        spent: 300000,
        rolloverMode: 'positive',
      );
      expect(carry, 200000);
    });

    test('positive mode floors an overspent period at zero, not a debt', () {
      final carry = applyRolloverStep(
        previousCarry: 0,
        budgeted: 500000,
        spent: 700000,
        rolloverMode: 'positive',
      );
      expect(carry, 0);
    });

    test('full mode lets an overspend carry forward as a negative', () {
      final carry = applyRolloverStep(
        previousCarry: 0,
        budgeted: 500000,
        spent: 700000,
        rolloverMode: 'full',
      );
      expect(carry, -200000);
    });

    test('full mode accumulates a negative carry across periods until spending recovers', () {
      var carry = 0.0;
      // Period 1: overspend by 200k.
      carry = applyRolloverStep(previousCarry: carry, budgeted: 500000, spent: 700000, rolloverMode: 'full');
      expect(carry, -200000);
      // Period 2: spend exactly the budget — the debt from period 1 still applies.
      carry = applyRolloverStep(previousCarry: carry, budgeted: 500000, spent: 500000, rolloverMode: 'full');
      expect(carry, -200000);
      // Period 3: underspend by 300k — clears the debt with 100k left over.
      carry = applyRolloverStep(previousCarry: carry, budgeted: 500000, spent: 200000, rolloverMode: 'full');
      expect(carry, 100000);
    });

    test('positive mode never lets a prior surplus paper over a later overspend below zero', () {
      var carry = 0.0;
      carry = applyRolloverStep(previousCarry: carry, budgeted: 500000, spent: 300000, rolloverMode: 'positive');
      expect(carry, 200000);
      // Overspend by more than the carried surplus.
      carry = applyRolloverStep(previousCarry: carry, budgeted: 500000, spent: 900000, rolloverMode: 'positive');
      expect(carry, 0, reason: 'positive mode floors at 0 even when a surplus was carried in');
    });
  });
}
