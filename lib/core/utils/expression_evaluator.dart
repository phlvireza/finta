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
