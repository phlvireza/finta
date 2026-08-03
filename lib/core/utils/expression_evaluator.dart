/// Evaluates a simple arithmetic expression (`+ - × ÷`, parentheses,
/// decimals) typed into the amount field's calculator — e.g. `"12000+3500"`
/// or `"45000/3"`. Returns null for anything that doesn't parse cleanly
/// (mismatched parens, trailing operators, division by zero) rather than
/// throwing, so callers can just fall back to "not a valid amount".
///
/// A hand-rolled recursive-descent parser rather than a package dependency —
/// the grammar is four rules and this is the only place in the app that
/// needs it.
double? evaluateExpression(String input) {
  // Accept the multiplication/division glyphs a calculator UI would show
  // ("×", "÷") alongside the plain-ASCII operators a keyboard produces.
  final normalized = input.replaceAll('×', '*').replaceAll('÷', '/').replaceAll(' ', '');
  if (normalized.isEmpty) return null;

  final parser = _ExpressionParser(normalized);
  final result = parser.parseExpression();
  if (result == null || !parser.isAtEnd) return null;
  return result;
}

/// Re-inserts thousand separators into an expression for *display* only —
/// `12000+3500` reads back as `12,000+3,500`.
///
/// The calculator keeps its expression raw (commas would break
/// [evaluateExpression], and [CurrencyInputFormatter] can't be reused here
/// since it is a strict numeric mask with no notion of operators), so the
/// grouping has to be applied at paint time instead.
///
/// Only the integer part of each numeric literal is grouped: digits after a
/// `.` are a fraction, not thousands, and grouping them would be wrong.
String formatExpressionWithSeparators(String expression) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < expression.length) {
    if (!_isDigit(expression[index])) {
      buffer.write(expression[index]);
      index++;
      continue;
    }

    final start = index;
    while (index < expression.length && _isDigit(expression[index])) {
      index++;
    }
    buffer.write(_groupDigits(expression.substring(start, index)));

    // A decimal point right after the integer part starts a fraction —
    // copy it and its digits through untouched.
    if (index < expression.length && expression[index] == '.') {
      buffer.write('.');
      index++;
      while (index < expression.length && _isDigit(expression[index])) {
        buffer.write(expression[index]);
        index++;
      }
    }
  }

  return buffer.toString();
}

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}

String _groupDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _ExpressionParser {
  final String _s;
  int _pos = 0;

  _ExpressionParser(this._s);

  bool get isAtEnd => _pos >= _s.length;

  String? get _current => isAtEnd ? null : _s[_pos];

  double? parseExpression() {
    var left = parseTerm();
    if (left == null) return null;

    while (_current == '+' || _current == '-') {
      final op = _current!;
      _pos++;
      final right = parseTerm();
      if (right == null) return null;
      left = op == '+' ? left! + right : left! - right;
    }
    return left;
  }

  double? parseTerm() {
    var left = parseFactor();
    if (left == null) return null;

    while (_current == '*' || _current == '/') {
      final op = _current!;
      _pos++;
      final right = parseFactor();
      if (right == null) return null;
      if (op == '*') {
        left = left! * right;
      } else {
        if (right == 0) return null;
        left = left! / right;
      }
    }
    return left;
  }

  double? parseFactor() {
    if (_current == '-') {
      _pos++;
      final value = parseFactor();
      return value == null ? null : -value;
    }
    if (_current == '(') {
      _pos++;
      final value = parseExpression();
      if (value == null || _current != ')') return null;
      _pos++;
      return value;
    }
    return _parseNumber();
  }

  double? _parseNumber() {
    final start = _pos;
    var sawDigit = false;
    var sawDot = false;
    while (!isAtEnd && (RegExp(r'\d').hasMatch(_s[_pos]) || (_s[_pos] == '.' && !sawDot))) {
      if (_s[_pos] == '.') sawDot = true;
      if (RegExp(r'\d').hasMatch(_s[_pos])) sawDigit = true;
      _pos++;
    }
    if (!sawDigit) return null;
    return double.tryParse(_s.substring(start, _pos));
  }
}
