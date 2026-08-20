import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/number_utils.dart';

void main() {
  group('formatCurrency', () {
    test('delegates to the shared amount formatter', () {
      expect(NumberUtils.formatCurrency(1500000), '1,500,000');
      expect(NumberUtils.formatCurrency(1500, symbol: 'Rp'), 'Rp 1,500');
    });

    test('renders decimals only when the currency uses them', () {
      expect(NumberUtils.formatCurrency(1500.75), '1,500');
      expect(NumberUtils.formatCurrency(1500.75, useDecimals: true), '1,500.75');
    });

    test('formats negatives without a stray separator', () {
      expect(NumberUtils.formatCurrency(-100), '-100');
      expect(NumberUtils.formatCurrency(-100000), '-100,000');
    });
  });

  group('formatPercentage', () {
    test('renders a ratio as a whole-number percentage', () {
      expect(NumberUtils.formatPercentage(0.75), '75%');
      expect(NumberUtils.formatPercentage(0), '0%');
      expect(NumberUtils.formatPercentage(1), '100%');
    });

    test('keeps going above 100 percent for overspend', () {
      expect(NumberUtils.formatPercentage(1.5), '150%');
    });

    test('rounds to the nearest whole percent', () {
      expect(NumberUtils.formatPercentage(0.756), '76%');
      expect(NumberUtils.formatPercentage(0.754), '75%');
    });

    test('handles a negative ratio', () {
      expect(NumberUtils.formatPercentage(-0.25), '-25%');
    });
  });

  group('parse', () {
    test('reverses the separator formatting', () {
      expect(NumberUtils.parse('1,500,000'), 1500000.0);
      expect(NumberUtils.parse('1,500.75'), 1500.75);
    });

    test('returns zero for input that is not a number', () {
      expect(NumberUtils.parse(''), 0.0);
      expect(NumberUtils.parse('n/a'), 0.0);
    });
  });

  group('formatCompact', () {
    test('abbreviates thousands, millions and billions', () {
      expect(NumberUtils.formatCompact(1500), '1.5K');
      expect(NumberUtils.formatCompact(1500000), '1.5M');
      expect(NumberUtils.formatCompact(1500000000), '1.5B');
    });

    test('drops a trailing .0 rather than showing 1.0K', () {
      expect(NumberUtils.formatCompact(1000), '1K');
      expect(NumberUtils.formatCompact(2000000), '2M');
      expect(NumberUtils.formatCompact(3000000000), '3B');
    });

    test('leaves values under a thousand unabbreviated', () {
      expect(NumberUtils.formatCompact(0), '0');
      expect(NumberUtils.formatCompact(999), '999');
    });

    test('switches unit exactly at each boundary', () {
      expect(NumberUtils.formatCompact(999), '999');
      expect(NumberUtils.formatCompact(1000), '1K');
      expect(NumberUtils.formatCompact(1000000), '1M');
      expect(NumberUtils.formatCompact(1000000000), '1B');
    });

    // Just under a boundary the rounded quotient reaches the next unit, so
    // 999,999 reads as "1000K" rather than promoting to "1M". Documenting the
    // behaviour rather than endorsing it.
    test('rounds up to a four-digit abbreviation just below a boundary', () {
      expect(NumberUtils.formatCompact(999999), '1000K');
    });

    test('prefixes the symbol without a space, unlike formatCurrency', () {
      expect(NumberUtils.formatCompact(1500, symbol: 'Rp'), 'Rp1.5K');
    });

    // Negatives fall to the else branch, since every threshold is a
    // greater-than test — so they are never abbreviated.
    test('does not abbreviate negatives', () {
      expect(NumberUtils.formatCompact(-1500), '-1500');
      expect(NumberUtils.formatCompact(-1500000), '-1500000');
    });
  });
}
