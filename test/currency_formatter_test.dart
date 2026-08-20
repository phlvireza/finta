import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/formatters/currency_formatter.dart';

void main() {
  group('formatAmount', () {
    test('groups thousands with commas', () {
      expect(formatAmount(1500), '1,500');
      expect(formatAmount(1500000), '1,500,000');
      expect(formatAmount(1234567890), '1,234,567,890');
    });

    test('leaves values below a thousand ungrouped', () {
      expect(formatAmount(0), '0');
      expect(formatAmount(7), '7');
      expect(formatAmount(999), '999');
    });

    // Regression: the sign used to be grouped as if it were a digit, so any
    // negative whose digit count was a multiple of three gained a separator
    // straight after the minus. Balances and net totals go negative in normal
    // use, so "-,100" reached the dashboard.
    test('does not insert a separator directly after the minus sign', () {
      expect(formatAmount(-100), '-100');
      expect(formatAmount(-999), '-999');
      expect(formatAmount(-100000), '-100,000');
      expect(formatAmount(-999999), '-999,999');
    });

    test('groups negatives the same way as positives', () {
      expect(formatAmount(-1500), '-1,500');
      expect(formatAmount(-1234567), '-1,234,567');
      expect(formatAmount(-50), '-50');
    });

    test('renders two decimal places when asked', () {
      expect(formatAmount(1500.75, useDecimals: true), '1,500.75');
      expect(formatAmount(1500.5, useDecimals: true), '1,500.50');
      expect(formatAmount(1500, useDecimals: true), '1,500.00');
    });

    // Regression: the fractional part was derived from the signed value, so it
    // carried its own minus and produced "-1,500.-75".
    test('takes the fraction from the magnitude for negatives', () {
      expect(formatAmount(-1500.75, useDecimals: true), '-1,500.75');
      expect(formatAmount(-0.5, useDecimals: true), '-0.50');
    });

    test('separates the symbol from the number with a space', () {
      expect(formatAmount(1500, symbol: 'Rp'), 'Rp 1,500');
      expect(formatAmount(-100, symbol: 'Rp'), 'Rp -100');
      expect(formatAmount(1500.75, symbol: r'$', useDecimals: true), r'$ 1,500.75');
    });

    test('omits the symbol entirely when it is empty', () {
      expect(formatAmount(1500, symbol: ''), '1,500');
    });

    test('truncates rather than rounds the integer part', () {
      expect(formatAmount(1500.99), '1,500');
    });
  });

  group('parseFormattedAmount', () {
    test('strips separators back to a number', () {
      expect(parseFormattedAmount('1,500'), 1500.0);
      expect(parseFormattedAmount('1,234,567'), 1234567.0);
    });

    test('keeps the decimal part', () {
      expect(parseFormattedAmount('1,500.75'), 1500.75);
    });

    test('round-trips what formatAmount produces', () {
      for (final value in [0.0, 999.0, 1500.0, 1234567.0, -100.0, -1500.0]) {
        expect(parseFormattedAmount(formatAmount(value)), value);
      }
    });

    test('falls back to zero on unparseable input', () {
      expect(parseFormattedAmount(''), 0.0);
      expect(parseFormattedAmount('abc'), 0.0);
      expect(parseFormattedAmount('Rp 1,500'), 0.0);
    });
  });

  group('CurrencyInputFormatter', () {
    TextEditingValue type(String text, {TextEditingValue? from, bool decimals = false}) {
      final formatter = CurrencyInputFormatter(allowDecimals: decimals);
      return formatter.formatEditUpdate(
        from ?? TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
    }

    test('inserts separators as digits are typed', () {
      expect(type('1500').text, '1,500');
      expect(type('1500000').text, '1,500,000');
    });

    test('passes an empty field through untouched', () {
      expect(type('').text, '');
    });

    test('strips leading zeros', () {
      expect(type('007').text, '7');
      expect(type('0').text, '0');
    });

    test('rejects non-numeric input by keeping the old value', () {
      const old = TextEditingValue(text: '1,500');
      expect(type('1500a', from: old).text, '1,500');
    });

    test('rejects more digits than maxDigits allows', () {
      final formatter = CurrencyInputFormatter(maxDigits: 4);
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '1,234'),
        const TextEditingValue(text: '12345'),
      );
      expect(result.text, '1,234');
    });

    test('accepts a decimal point only when decimals are allowed', () {
      expect(type('1500.75', decimals: true).text, '1,500.75');
      const old = TextEditingValue(text: '1,500');
      expect(type('1500.75', from: old).text, '1,500');
    });

    test('caps the decimal part at two digits', () {
      expect(type('1500.759', decimals: true).text, '1,500.75');
    });

    test('rejects a second decimal point', () {
      const old = TextEditingValue(text: '1,500.7');
      expect(type('1500.7.5', from: old, decimals: true).text, '1,500.7');
    });
  });
}
