import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/amount_field_fit.dart';

void main() {
  group('fitAmountFontSize', () {
    test('keeps the full size when the amount comfortably fits', () {
      // 4 chars * 48 * 0.62 ≈ 119px, well inside 300px.
      expect(
        fitAmountFontSize(characterCount: 4, maxWidth: 300),
        48,
      );
    });

    test('shrinks a long amount so it fits the available width', () {
      // "1,500,000" is 9 chars; at 48px it needs ~268px but only 200 exist.
      final size = fitAmountFontSize(characterCount: 9, maxWidth: 200);

      expect(size, lessThan(48));
      expect(size * 9 * 0.62, closeTo(200, 0.01));
    });

    test('never shrinks below the floor, even for the longest input', () {
      // 15 digits + 4 separators is the most CurrencyInputFormatter allows.
      expect(
        fitAmountFontSize(characterCount: 19, maxWidth: 60, minFontSize: 16),
        16,
      );
    });

    test('an empty field keeps the full size rather than dividing by zero', () {
      expect(fitAmountFontSize(characterCount: 0, maxWidth: 300), 48);
    });

    test('a non-positive width falls back to the full size', () {
      // Can happen for one frame before layout has real constraints —
      // better a too-big hint than a NaN or a negative font size.
      expect(fitAmountFontSize(characterCount: 6, maxWidth: 0), 48);
      expect(fitAmountFontSize(characterCount: 6, maxWidth: -20), 48);
    });

    test('shrinks monotonically as the amount grows', () {
      final sizes = [6, 9, 12, 15]
          .map((n) => fitAmountFontSize(characterCount: n, maxWidth: 200))
          .toList();

      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i], lessThanOrEqualTo(sizes[i - 1]));
      }
    });
  });
}
