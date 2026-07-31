/// Shared spacing, sizing, and duration constants.
class AppConstants {
  AppConstants._();

  // ── Spacing Scale ─────────────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXxl = 24.0;
  static const double spacingXxxl = 32.0;

  // ── Border Radius ─────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  // ── Animation Durations ───────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 350);

  // ── Input Constraints ─────────────────────────────────────
  static const int maxAmountDigits = 15;
  static const int maxDecimalPlaces = 2;
  static const int maxNoteLength = 200;

  // ── Dashboard ─────────────────────────────────────────────
  static const int recentTransactionCount = 10;
  static const int budgetOverviewCount = 5;
  static const int upcomingBillsCount = 3;

  // ── Layout ────────────────────────────────────────────────
  /// Bottom padding so scrollable content clears the FAB and nav bar.
  static const double fabClearance = 100.0;

  // ── Budget Thresholds ─────────────────────────────────────
  static const double budgetWarningThreshold = 0.75;
  static const double budgetExceededThreshold = 1.0;

  // ── Currencies ────────────────────────────────────────────
  static const List<CurrencyOption> currencies = [
    CurrencyOption(symbol: 'Rp', name: 'Indonesian Rupiah', code: 'IDR', useDecimals: false),
    CurrencyOption(symbol: '\$', name: 'US Dollar', code: 'USD', useDecimals: true),
    CurrencyOption(symbol: '€', name: 'Euro', code: 'EUR', useDecimals: true),
    CurrencyOption(symbol: '£', name: 'British Pound', code: 'GBP', useDecimals: true),
    CurrencyOption(symbol: '¥', name: 'Japanese Yen', code: 'JPY', useDecimals: false),
  ];
}

/// Represents a selectable currency option.
class CurrencyOption {
  final String symbol;
  final String name;
  final String code;
  final bool useDecimals;

  const CurrencyOption({
    required this.symbol,
    required this.name,
    required this.code,
    required this.useDecimals,
  });
}
