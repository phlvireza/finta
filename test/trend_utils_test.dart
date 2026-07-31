import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/trend_utils.dart';

void main() {
  group('trendVsAverage', () {
    test('flags the latest month as above the average of prior months', () {
      final result = trendVsAverage([100, 100, 100, 132]);
      expect(result, isNotNull);
      expect(result!.isAbove, isTrue);
      expect(result.percent, closeTo(32, 0.01));
    });

    test('flags the latest month as below the average of prior months', () {
      final result = trendVsAverage([100, 100, 100, 60]);
      expect(result, isNotNull);
      expect(result!.isAbove, isFalse);
      expect(result.percent, closeTo(40, 0.01));
    });

    test('returns null with fewer than two months of data', () {
      expect(trendVsAverage([100]), isNull);
      expect(trendVsAverage([]), isNull);
    });

    test('returns null when the prior average is zero', () {
      expect(trendVsAverage([0, 0, 0, 50]), isNull);
    });

    test('an unchanged trend produces a zero-percent, non-above result', () {
      final result = trendVsAverage([100, 100, 100]);
      expect(result, isNotNull);
      expect(result!.percent, 0);
      expect(result.isAbove, isFalse);
    });
  });
}
