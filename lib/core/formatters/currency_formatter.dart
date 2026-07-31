import 'package:flutter/services.dart';

/// Custom [TextInputFormatter] that auto-inserts thousand-separator commas
/// as the user types a numeric amount.
///
/// Examples: 1500 → 1,500 | 1500000 → 1,500,000
class CurrencyInputFormatter extends TextInputFormatter {
  final bool allowDecimals;
  final int maxDigits;

  CurrencyInputFormatter({
    this.allowDecimals = false,
    this.maxDigits = 15,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty input
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String newText = newValue.text;
    int selectionIndex = newValue.selection.end;

    // Handle backspacing over a comma
    if (oldValue.text.length > newText.length) {
      int diff = oldValue.text.length - newText.length;
      if (diff == 1 && selectionIndex >= 0 && selectionIndex < oldValue.text.length) {
        if (oldValue.text[selectionIndex] == ',') {
          // A comma was deleted, so we should delete the digit before it instead
          if (selectionIndex > 0) {
            newText = newText.substring(0, selectionIndex - 1) + newText.substring(selectionIndex);
            selectionIndex -= 1;
          }
        }
      }
    }

    // Strip all existing commas to get raw input
    String raw = newText.replaceAll(',', '');

    // Handle decimal point
    String integerPart = raw;
    String decimalPart = '';

    if (allowDecimals && raw.contains('.')) {
      final parts = raw.split('.');
      if (parts.length > 2) {
        // More than one decimal point — reject
        return oldValue;
      }
      integerPart = parts[0];
      decimalPart = parts[1];

      // Cap decimal to 2 digits
      if (decimalPart.length > 2) {
        decimalPart = decimalPart.substring(0, 2);
      }
    }

    // Validate integer part is numeric only
    if (integerPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(integerPart)) {
      return oldValue;
    }

    // Validate decimal part is numeric only
    if (decimalPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(decimalPart)) {
      return oldValue;
    }

    // Remove leading zeros (except for "0" or "0.")
    if (integerPart.length > 1) {
      integerPart = integerPart.replaceFirst(RegExp(r'^0+'), '');
      if (integerPart.isEmpty) integerPart = '0';
    }

    // Cap digit length
    if (integerPart.length > maxDigits) {
      return oldValue;
    }

    // Insert commas every 3 digits from the right
    final formatted = _insertCommas(integerPart);

    // Rebuild full string
    String result = formatted;
    if (allowDecimals && raw.contains('.')) {
      result = '$formatted.$decimalPart';
    }

    // Heuristically calculate new cursor position
    // Count how many non-comma characters are before the cursor in the old text
    int rawCursor = 0;
    for (int i = 0; i < selectionIndex && i < newText.length; i++) {
      if (newText[i] != ',') rawCursor++;
    }

    int newCursorOffset = 0;
    int currentRaw = 0;
    for (int i = 0; i < result.length; i++) {
      if (currentRaw == rawCursor) {
        newCursorOffset = i;
        break;
      }
      if (result[i] != ',') currentRaw++;
    }
    if (currentRaw == rawCursor) newCursorOffset = result.length;

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }

  /// Insert commas as thousand separators.
  String _insertCommas(String digits) {
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    final length = digits.length;
    for (var i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// Strip commas from a formatted string and parse to double.
double parseFormattedAmount(String formatted) {
  final raw = formatted.replaceAll(',', '');
  return double.tryParse(raw) ?? 0.0;
}

/// Format a raw number with commas and optional currency symbol.
String formatAmount(double amount, {String symbol = '', bool useDecimals = false}) {
  final intPart = amount.truncate();
  final buffer = StringBuffer();

  final digits = intPart.toString();
  final length = digits.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }

  String result = buffer.toString();

  if (useDecimals) {
    final decPart = ((amount - intPart) * 100).round().toString().padLeft(2, '0');
    result = '$result.$decPart';
  }

  if (symbol.isNotEmpty) {
    result = '$symbol $result';
  }

  return result;
}
