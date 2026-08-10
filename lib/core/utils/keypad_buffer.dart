/// Key-press reducer for the in-app amount keypad.
///
/// The keypad edits a raw arithmetic expression string (`"12000+3500"`),
/// which [evaluateExpression] later collapses to a number. Keeping the
/// reduction here — pure, no Flutter — is what makes the fiddly rules below
/// testable without pumping a widget tree.
///
/// The keypad is the *only* way to type an amount, so every guard a physical
/// keyboard would have made optional has to live here: you cannot land on
/// `"5..3"`, `"7++2"`, or a 40-digit number by mashing keys.
library;

const String _operators = '+-*/';

/// Digits allowed in a single numeric literal, matching
/// `AppConstants.maxAmountDigits`. Duplicated as a plain literal rather than
/// imported so this file stays free of app-layer imports; the keypad passes
/// the real constant in via [maxDigits].
const int _defaultMaxDigits = 15;

/// Applies one key press to [expression] and returns the new expression.
///
/// [key] is one of: a single digit `0`-`9`, `'00'`, `'000'`, `'.'`, one of
/// `+ - * /`, or `'backspace'` / `'clear'`. Anything else is returned
/// unchanged.
///
/// [allowDecimals] is false for no-decimal currencies (IDR, JPY) — there the
/// `.` key is inert rather than hidden, so the grid keeps its shape.
String applyKeypadKey(
  String expression,
  String key, {
  required bool allowDecimals,
  int maxDigits = _defaultMaxDigits,
}) {
  switch (key) {
    case 'clear':
      return '';
    case 'backspace':
      return expression.isEmpty
          ? expression
          : expression.substring(0, expression.length - 1);
    case '.':
      return allowDecimals ? _appendDot(expression) : expression;
    case '00':
    case '000':
      return _appendZeros(expression, key.length, maxDigits);
  }

  if (_operators.contains(key) && key.length == 1) {
    return _appendOperator(expression, key);
  }
  if (key.length == 1 && _isDigit(key)) {
    return _appendDigit(expression, key, maxDigits);
  }
  return expression;
}

/// True when [expression] is ready to be read as a final amount — no
/// dangling operator, no bare `"."`. The keypad's Done/`=` path checks this
/// before handing the string to `evaluateExpression`.
bool isKeypadExpressionComplete(String expression) {
  if (expression.isEmpty) return false;
  final last = expression[expression.length - 1];
  return !_operators.contains(last) && last != '.';
}

String _appendDigit(String expression, String digit, int maxDigits) {
  final literal = _trailingLiteral(expression);

  // A lone leading zero is a placeholder, not a value: "0" then "5" is 5,
  // not 05. Only collapse when there is no decimal point in play, so
  // "0.5" keeps its zero.
  if (literal == '0') {
    return '${expression.substring(0, expression.length - 1)}$digit';
  }

  if (_digitCount(literal) >= maxDigits) return expression;
  return '$expression$digit';
}

/// `000` is the whole point of this keypad on IDR amounts. It is a shorthand
/// for repeated zeros, so it behaves as one — except on an empty buffer or a
/// fresh operand, where "000" would be a nonsense literal and a single `0`
/// is what the user meant.
String _appendZeros(String expression, int count, int maxDigits) {
  final literal = _trailingLiteral(expression);
  if (literal.isEmpty || literal == '0') {
    return literal == '0' ? expression : '${expression}0';
  }

  final room = maxDigits - _digitCount(literal);
  if (room <= 0) return expression;
  return expression + '0' * (count < room ? count : room);
}

String _appendDot(String expression) {
  final literal = _trailingLiteral(expression);
  if (literal.contains('.')) return expression;
  // A dot opening a new operand needs a leading zero to parse: "5+.2" is
  // rejected by the evaluator, "5+0.2" is not.
  if (literal.isEmpty) return '${expression}0.';
  return '$expression.';
}

/// Operators replace rather than stack — tapping `+` then `×` means the user
/// changed their mind, which is what every calculator does. A leading
/// operator is dropped entirely except `-`, which is a valid unary minus.
String _appendOperator(String expression, String op) {
  if (expression.isEmpty) return op == '-' ? op : expression;

  final last = expression[expression.length - 1];
  if (_operators.contains(last)) {
    return '${expression.substring(0, expression.length - 1)}$op';
  }
  // "5." + "+" would leave a trailing dot inside the literal; drop it.
  if (last == '.') {
    return '${expression.substring(0, expression.length - 1)}$op';
  }
  return '$expression$op';
}

/// The numeric literal currently being typed — everything after the last
/// operator. Empty when the expression ends on an operator.
String _trailingLiteral(String expression) {
  var start = expression.length;
  while (start > 0 && !_operators.contains(expression[start - 1])) {
    start--;
  }
  return expression.substring(start);
}

int _digitCount(String literal) {
  var count = 0;
  for (var i = 0; i < literal.length; i++) {
    if (_isDigit(literal[i])) count++;
  }
  return count;
}

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}
