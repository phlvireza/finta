import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/keypad_buffer.dart';

/// Convenience wrapper — most cases care about the decimal-currency path.
String press(String expression, String key, {bool allowDecimals = true, int maxDigits = 15}) =>
    applyKeypadKey(expression, key, allowDecimals: allowDecimals, maxDigits: maxDigits);

/// Types a whole sequence of keys, so tests can read like the taps a user
/// actually makes.
String type(List<String> keys, {bool allowDecimals = true, int maxDigits = 15}) {
  var expression = '';
  for (final key in keys) {
    expression = applyKeypadKey(expression, key,
        allowDecimals: allowDecimals, maxDigits: maxDigits);
  }
  return expression;
}

void main() {
  group('digits', () {
    test('appends digits in order', () {
      expect(type(['1', '2', '3']), '123');
    });

    test('collapses a lone leading zero', () {
      expect(type(['0', '5']), '5');
    });

    test('keeps a leading zero that opens a decimal', () {
      expect(type(['0', '.', '5']), '0.5');
    });

    test('collapses a leading zero on a fresh operand, not the whole expression', () {
      expect(type(['5', '+', '0', '7']), '5+7');
    });

    test('caps digits per literal', () {
      expect(type(['1', '2', '3', '4'], maxDigits: 3), '123');
    });

    test('the digit cap applies per operand, not per expression', () {
      expect(type(['1', '2', '3', '+', '4', '5', '6'], maxDigits: 3), '123+456');
    });
  });

  group('000 shorthand', () {
    test('expands to three zeros after a value', () {
      expect(type(['1', '2', '000']), '12000');
    });

    test('on an empty buffer yields a single zero', () {
      expect(press('', '000'), '0');
    });

    test('on a lone zero stays a single zero', () {
      expect(type(['0', '000']), '0');
    });

    test('opening a fresh operand yields a single zero', () {
      expect(type(['5', '+', '000']), '5+0');
    });

    test('truncates to the remaining digit budget rather than overflowing', () {
      expect(type(['1', '000'], maxDigits: 3), '100');
    });

    test('is inert once the cap is reached', () {
      expect(type(['1', '2', '3', '000'], maxDigits: 3), '123');
    });

    test('00 expands to two zeros', () {
      expect(type(['7', '00']), '700');
    });
  });

  group('decimal point', () {
    test('is inert for no-decimal currencies', () {
      expect(type(['5', '.', '2'], allowDecimals: false), '52');
    });

    test('only one per literal', () {
      expect(type(['1', '.', '5', '.', '2']), '1.52');
    });

    test('allows a second one in a later operand', () {
      expect(type(['1', '.', '5', '+', '2', '.', '3']), '1.5+2.3');
    });

    test('opening an operand gets a leading zero so it parses', () {
      expect(type(['5', '+', '.', '2']), '5+0.2');
    });

    test('on an empty buffer gets a leading zero', () {
      expect(type(['.', '5']), '0.5');
    });
  });

  group('operators', () {
    test('a second operator replaces the first', () {
      expect(type(['5', '+', '*']), '5*');
    });

    test('a leading minus is kept as unary', () {
      expect(press('', '-'), '-');
    });

    test('a leading plus is dropped', () {
      expect(press('', '+'), '');
    });

    test('drops a dangling decimal point before the operator', () {
      expect(type(['5', '.', '+']), '5+');
    });
  });

  group('backspace and clear', () {
    test('backspace removes the last character', () {
      expect(press('123', 'backspace'), '12');
    });

    test('backspace on an empty buffer is a no-op', () {
      expect(press('', 'backspace'), '');
    });

    test('clear empties the buffer', () {
      expect(press('12+34', 'clear'), '');
    });
  });

  test('unknown keys are ignored', () {
    expect(press('12', 'x'), '12');
  });

  group('isKeypadExpressionComplete', () {
    test('rejects an empty buffer', () {
      expect(isKeypadExpressionComplete(''), isFalse);
    });

    test('rejects a trailing operator', () {
      expect(isKeypadExpressionComplete('12+'), isFalse);
    });

    test('rejects a trailing decimal point', () {
      expect(isKeypadExpressionComplete('12.'), isFalse);
    });

    test('accepts a finished expression', () {
      expect(isKeypadExpressionComplete('12+34'), isTrue);
    });

    test('accepts a plain number', () {
      expect(isKeypadExpressionComplete('12000'), isTrue);
    });
  });
}
