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

  /// Upper bound every amount validator enforces. Well under what
  /// [maxAmountDigits] allows to be typed — the formatter's job is masking,
  /// this is the sanity check that a fat-fingered extra digit run doesn't
  /// silently become a real balance.
  static const double maxAmount = 999999999999;

  // ── Dashboard ─────────────────────────────────────────────
  static const int recentTransactionCount = 10;
  static const int upcomingBillsCount = 3;

  // ── Layout ────────────────────────────────────────────────
  /// Bottom padding so scrollable content clears the FAB and nav bar.
  static const double fabClearance = 100.0;

  /// Cap for a centered content column on a wide screen. Keeps full-width
  /// controls tied to the text above them instead of stretching across a
  /// tablet or a landscape window.
  static const double maxContentWidth = 400.0;

  /// Height of a primary or secondary button anywhere in the app. Enforced in
  /// the theme via `minimumSize`, so a bare `ElevatedButton` matches a
  /// full-width one in a form footer.
  static const double buttonHeight = 52.0;

  // ── Budget Thresholds ─────────────────────────────────────
  static const double budgetWarningThreshold = 0.75;
  static const double budgetExceededThreshold = 1.0;

  // ── Tinted surfaces ────────────────────────────────────────
  /// Alpha for an identity chip (category/account icon on its own color) and
  /// a status pill (badge text on its own color). One value, used everywhere
  /// a source color needs a background instead of five different ones.
  static const double tintAlpha = 0.12;

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
