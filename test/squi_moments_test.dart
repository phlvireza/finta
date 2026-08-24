import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/squi_moments.dart';

void main() {
  String keyFor(SquiMoment moment) => moment.name;

  group('selectSquiMoment', () {
    test('returns null when nothing is eligible', () {
      expect(
        selectSquiMoment(eligible: {}, alreadyCelebrated: {}, keyFor: keyFor),
        isNull,
      );
    });

    test('uses product priority and skips consumed moments', () {
      expect(
        selectSquiMoment(
          eligible: {SquiMoment.firstTransaction, SquiMoment.goalReached},
          alreadyCelebrated: {},
          keyFor: keyFor,
        ),
        SquiMoment.goalReached,
      );
      expect(
        selectSquiMoment(
          eligible: {SquiMoment.firstTransaction, SquiMoment.goalReached},
          alreadyCelebrated: {SquiMoment.goalReached.name},
          keyFor: keyFor,
        ),
        SquiMoment.firstTransaction,
      );
    });

    test('returns null when every eligible moment was consumed', () {
      expect(
        selectSquiMoment(
          eligible: {SquiMoment.debtSettled},
          alreadyCelebrated: {SquiMoment.debtSettled.name},
          keyFor: keyFor,
        ),
        isNull,
      );
    });
  });

  group('shouldCelebrateRecap', () {
    test('requires a completed, comparable, improving positive period', () {
      expect(
        shouldCelebrateRecap(
          isInProgress: false,
          totalIncome: 100,
          previousIncome: 100,
          savingsRate: .4,
          previousSavingsRate: .2,
        ),
        isTrue,
      );
      expect(
        shouldCelebrateRecap(
          isInProgress: true,
          totalIncome: 100,
          previousIncome: 100,
          savingsRate: .4,
          previousSavingsRate: .2,
        ),
        isFalse,
      );
      expect(
        shouldCelebrateRecap(
          isInProgress: false,
          totalIncome: 100,
          previousIncome: 0,
          savingsRate: .4,
          previousSavingsRate: 0,
        ),
        isFalse,
      );
    });
  });
}
