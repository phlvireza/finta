import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/anomaly_detector.dart';

void main() {
  group('detectAnomaly', () {
    test('returns null until there is enough history to judge', () {
      expect(detectAnomaly(500, []), isNull);
      expect(detectAnomaly(500, [10, 10, 10, 10]), isNull);
    });

    test('starts judging once minHistory is met', () {
      expect(detectAnomaly(500, [10, 12, 11, 9, 13]), isNotNull);
    });

    test('respects a caller-supplied minHistory', () {
      expect(detectAnomaly(500, [10, 12]), isNull);
      expect(detectAnomaly(500, [10, 12], minHistory: 2), isNotNull);
    });

    test('flags a spend far above the usual range', () {
      final result = detectAnomaly(500, [100, 110, 95, 105, 100]);
      expect(result, isNotNull);
      expect(result!.isAnomaly, isTrue);
      expect(result.zScore, greaterThan(2.5));
    });

    test('leaves an ordinary spend unflagged', () {
      final result = detectAnomaly(105, [100, 110, 95, 105, 100]);
      expect(result!.isAnomaly, isFalse);
    });

    // An unusually *small* purchase is not what a "did you mean to spend this
    // much?" nudge is for, so only the upper tail is flagged.
    test('never flags a spend below the mean, however far below', () {
      final result = detectAnomaly(1, [100, 110, 95, 105, 100]);
      expect(result!.isAnomaly, isFalse);
      expect(result.zScore, lessThan(0));
    });

    test('reports the mean of the history it was given', () {
      final result = detectAnomaly(500, [100, 200, 300, 400, 500]);
      expect(result!.mean, 300);
    });

    test('a higher threshold suppresses an otherwise-flagged spend', () {
      final history = [100.0, 110.0, 95.0, 105.0, 100.0];
      expect(detectAnomaly(500, history)!.isAnomaly, isTrue);
      expect(detectAnomaly(500, history, zThreshold: 100)!.isAnomaly, isFalse);
    });

    group('when every prior amount is identical', () {
      // Standard deviation is zero, so the z-score is undefined; the detector
      // falls back to a 50%-above-mean rule instead of dividing by zero.
      final flat = [100.0, 100.0, 100.0, 100.0, 100.0];

      test('reports an infinite z-score rather than NaN', () {
        expect(detectAnomaly(200, flat)!.zScore, double.infinity);
      });

      test('flags an amount more than half again the mean', () {
        expect(detectAnomaly(200, flat)!.isAnomaly, isTrue);
      });

      test('leaves a modest increase unflagged', () {
        expect(detectAnomaly(120, flat)!.isAnomaly, isFalse);
        expect(detectAnomaly(150, flat)!.isAnomaly, isFalse);
      });

      test('leaves an identical amount unflagged', () {
        expect(detectAnomaly(100, flat)!.isAnomaly, isFalse);
      });
    });

    test('handles an all-zero history without dividing by zero', () {
      final result = detectAnomaly(50, [0, 0, 0, 0, 0]);
      expect(result, isNotNull);
      expect(result!.mean, 0);
      // mean * 1.5 is 0, and 50 > 0, so a first non-zero spend is flagged.
      expect(result.isAnomaly, isTrue);
    });
  });
}
