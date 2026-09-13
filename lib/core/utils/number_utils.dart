import '../formatters/currency_formatter.dart';
import 'package:intl/intl.dart';

/// Number formatting and parsing helpers.
class NumberUtils {
  NumberUtils._();

  /// Format amount with commas and currency symbol.
  /// e.g. formatCurrency(1500000, 'Rp', false) → "Rp 1,500,000"
  static String formatCurrency(
    double amount, {
    String symbol = '',
    bool useDecimals = false,
  }) {
    return formatAmount(amount, symbol: symbol, useDecimals: useDecimals);
  }

  /// Locale-aware display formatting for financial summaries and charts.
  ///
  /// Input fields intentionally keep their existing stable comma-based
  /// formatter; this method is for read-only UI where the selected app locale
  /// should control grouping, decimals, and symbol placement.
  static String formatCurrencyLocalized(
    double amount, {
    required String locale,
    required String symbol,
    required bool useDecimals,
  }) {
    return NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: useDecimals ? 2 : 0,
    ).format(amount);
  }

  /// Compact locale-aware currency for chart axes.
  static String formatCompactCurrencyLocalized(
    double amount, {
    required String locale,
    required String symbol,
  }) {
    return NumberFormat.compactCurrency(
      locale: locale,
      symbol: symbol,
      decimalDigits: 1,
    ).format(amount);
  }

  /// Format a percentage value (0.0 to 1.0+) as "75%".
  static String formatPercentage(double ratio) {
    return '${(ratio * 100).toStringAsFixed(0)}%';
  }

  /// Parse a comma-formatted string back to double.
  static double parse(String formatted) {
    return parseFormattedAmount(formatted);
  }

  /// Format a large number compactly (e.g. 1.5K, 2M)
  static String formatCompact(double amount, {String symbol = ''}) {
    String result;
    if (amount >= 1000000000) {
      result = '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (amount >= 1000000) {
      result = '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      result = '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      result = amount.toStringAsFixed(0);
    }

    // Clean up .0
    if (result.endsWith('.0K')) result = result.replaceAll('.0K', 'K');
    if (result.endsWith('.0M')) result = result.replaceAll('.0M', 'M');
    if (result.endsWith('.0B')) result = result.replaceAll('.0B', 'B');

    if (symbol.isNotEmpty) {
      return '$symbol$result';
    }
    return result;
  }
}
