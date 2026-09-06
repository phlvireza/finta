import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/formatters/currency_formatter.dart';

void main() {
  test('rounding cents carries into whole units and thousands', () {
    for (final value in [0.999, 1.999, 999.999, 999999.999]) {
      final expected = formatAmount(value.roundToDouble());
      expect(formatAmount(value, useDecimals: true), '$expected.00');
      expect(formatAmount(-value, useDecimals: true), '-$expected.00');
    }
    expect(formatAmount(1.994, useDecimals: true), '1.99');
    expect(formatAmount(1.999), '1');
  });
}
