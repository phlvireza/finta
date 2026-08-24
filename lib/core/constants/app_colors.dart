import 'package:flutter/material.dart';

/// Squirio color palette — warm & earthy tones.
/// See PRD Section 3 for the full color table.
class AppColors {
  AppColors._();

  // ── Light Mode ──────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFFAF7F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0EBE3);
  static const Color lightPrimary = Color(0xFFC87941);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF2C2520);
  static const Color lightTextSecondary = Color(0xFF8A7E74);
  static const Color lightIncome = Color(0xFF5B8C5A);
  static const Color lightExpense = Color(0xFFC2665A);
  static const Color lightBorder = Color(0xFFE5DED5);

  // ── Dark Mode ───────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF1A1816);
  static const Color darkSurface = Color(0xFF242120);
  static const Color darkSurfaceVariant = Color(0xFF2E2A27);
  static const Color darkPrimary = Color(0xFFD4956A);
  static const Color darkOnPrimary = Color(0xFF1A1816);
  static const Color darkTextPrimary = Color(0xFFEDE8E2);
  static const Color darkTextSecondary = Color(0xFF9C8E82);
  static const Color darkIncome = Color(0xFF7DB87C);
  static const Color darkExpense = Color(0xFFD4887E);
  static const Color darkBorder = Color(0xFF3A3533);

  // ── Shared / Semantic ───────────────────────────────────────
  static const Color warning = Color(0xFFD4A05A);
  static const Color warningLight = Color(0xFFF5E6CC);
  static const Color warningDark = Color(0xFF3D3225);

  /// Chart palette for donut/pie category charts.
  ///
  /// The previous 9-color "warm & earthy" set looked coherent as swatches
  /// but six of its nine hues fell below the chroma floor a categorical
  /// color needs to actually read as an identity rather than a shade of
  /// gray, and the worst adjacent pair (teal-grey vs mauve) measured
  /// ΔE 8.1 under normal vision — indistinguishable at a glance even for a
  /// full-color viewer, let alone under color-vision deficiency.
  ///
  /// This set was built and checked with the data-viz skill's
  /// `validate_palette` script rather than eyeballed: every hue clears the
  /// OKLCH lightness band and chroma floor for its mode, the worst adjacent
  /// pair (including the ring's wraparound, since a donut's last slice sits
  /// next to its first) clears both the CVD-simulated and normal-vision
  /// separation floors, and light/dark use the *same* hue order — only
  /// lightness/chroma are re-stepped per mode — so a category never changes
  /// hue family when the user toggles theme. Two hues from the original
  /// nine (a near-duplicate second green, and an amber close enough to
  /// [warning] to risk reading as a status color rather than a category)
  /// were dropped rather than forced to fit; seven well-separated hues beat
  /// nine crowded ones. Order is load-bearing — re-run the validator before
  /// reordering or adding a hue, not just before changing a hex.
  static const List<Color> chartColorsLight = [
    Color(0xFF3F8B4C), // green
    Color(0xFF7B5B9E), // mauve
    Color(0xFFC13F55), // rose
    Color(0xFF12928C), // teal
    Color(0xFFA0522D), // sienna
    Color(0xFF2E5FA8), // blue
    Color(0xFFC1661E), // terracotta
  ];

  static const List<Color> chartColorsDark = [
    Color(0xFF4F9E4F), // green
    Color(0xFF7C63B8), // mauve
    Color(0xFFC24F62), // rose
    Color(0xFF14A69D), // teal
    Color(0xFFB36A3E), // sienna
    Color(0xFF4779C4), // blue
    Color(0xFFC96B2E), // terracotta
  ];

  /// Resolves the bar colour for a budget's spending state — shared by
  /// `BudgetProgressBar` and the aggregate donut on the budgets screen so
  /// both agree on what a given ratio means instead of maintaining two
  /// copies of the same threshold ladder.
  static Color budgetBarColor({
    required bool isExceeded,
    required bool isWarning,
    required Color categoryColor,
    required bool isDark,
  }) {
    if (isExceeded) return isDark ? darkExpense : lightExpense;
    if (isWarning) return warning;
    return categoryColor;
  }

  /// The swatch picker offered when creating/editing an account or a
  /// category — was duplicated verbatim as a private `_colorOptions` list in
  /// both forms. Hex strings (not [Color]s) because that's the format the
  /// account/category `color` field is stored and compared in.
  ///
  /// Every colour [SeedData] assigns appears here, so opening a default
  /// category shows its swatch already selected. `#D4A05A` was dropped: it
  /// is [warning] exactly, and a category wearing the "over budget" amber
  /// as its identity is a colour collision waiting to confuse someone.
  ///
  /// `#7A8B6F` (Donation) was missing until default categories became
  /// editable — nothing could open that category before, so the gap was
  /// invisible. Opening it showed no swatch selected and no way back to
  /// its original colour. Anything added to [SeedData] belongs here too.
  static const List<String> swatchOptions = [
    '#3F8B4C', '#2E5FA8', '#C13F55', '#12928C', '#A0522D', '#7B5B9E',
    '#C1661E', '#C87941', '#5B8C5A', '#C2665A', '#7A8B6F', '#8A7E74',
  ];
}
