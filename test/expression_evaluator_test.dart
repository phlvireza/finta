import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/expression_evaluator.dart';

void main() {
  group('evaluateExpression', () {
    test('adds and subtracts left to right', () {
      expect(evaluateExpression('12000+3500'), 15500);
      expect(evaluateExpression('12000-3500-500'), 8000);
    });

    test('applies multiplication and division first', () {
      expect(evaluateExpression('1000+2*500'), 2000);
      expect(evaluateExpression('45000/3'), 15000);
    });

    test('accepts the glyphs the calculator keypad shows', () {
      expect(evaluateExpression('2×3'), 6);
      expect(evaluateExpression('9÷3'), 3);
    });

    test('returns null instead of throwing on unusable input', () {
      expect(evaluateExpression(''), isNull);
      expect(evaluateExpression('1200+'), isNull, reason: 'trailing operator');
      expect(evaluateExpression('(1+2'), isNull, reason: 'unclosed paren');
      expect(evaluateExpression('5/0'), isNull, reason: 'division by zero');
    });
  });

  group('formatExpressionWithSeparators', () {
    test('groups each numeric literal in an expression', () {
      expect(formatExpressionWithSeparators('12000+3500'), '12,000+3,500');
      expect(formatExpressionWithSeparators('45000/3'), '45,000/3');
    });

    test('groups only the integer part, never the fraction', () {
      expect(formatExpressionWithSeparators('1234.5678'), '1,234.5678');
      expect(formatExpressionWithSeparators('1500000.25'), '1,500,000.25');
    });

    test('leaves operators and parentheses untouched', () {
      expect(
        formatExpressionWithSeparators('(12000+3500)×2'),
        '(12,000+3,500)×2',
      );
    });

    test('handles a partially typed expression', () {
      // The display formats on every keystroke, including mid-entry.
      expect(formatExpressionWithSeparators(''), '');
      expect(formatExpressionWithSeparators('1200+'), '1,200+');
      expect(formatExpressionWithSeparators('.5'), '.5');
    });

    test('leaves numbers under four digits alone', () {
      expect(formatExpressionWithSeparators('999'), '999');
      expect(formatExpressionWithSeparators('1000'), '1,000');
    });

    test('output still evaluates once the commas are stripped', () {
      final display = formatExpressionWithSeparators('12000+3500');
      expect(evaluateExpression(display.replaceAll(',', '')), 15500);
    });
  });
}
