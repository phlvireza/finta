import 'package:flutter/material.dart';

/// Finta color palette — warm & earthy tones.
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

  /// Chart palette — hand-picked warm tones for donut/pie charts.
  static const List<Color> chartColorsLight = [
    Color(0xFFC87941), // terracotta
    Color(0xFF5B8C5A), // sage green
    Color(0xFFC2665A), // dusty rose
    Color(0xFFD4A05A), // warm amber
    Color(0xFF7A8B6F), // olive
    Color(0xFFB07A5B), // sienna
    Color(0xFF8B6F7A), // mauve
    Color(0xFF6F8B8A), // teal-grey
    Color(0xFFCBA882), // sand
  ];

  static const List<Color> chartColorsDark = [
    Color(0xFFD4956A), // soft amber
    Color(0xFF7DB87C), // sage green
    Color(0xFFD4887E), // dusty rose
    Color(0xFFE5B878), // warm gold
    Color(0xFF95A883), // olive
    Color(0xFFC89470), // sienna
    Color(0xFFA88895), // mauve
    Color(0xFF88A5A4), // teal-grey
    Color(0xFFDFC09A), // sand
  ];

  /// Resolves the bar colour for a budget's spending state — shared by
  /// `BudgetProgressBar` and `BudgetOverview` so both screens agree on
  /// what a given ratio means instead of maintaining two copies of the
  /// same threshold ladder.
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

  /// Default category colors for seeding.
  static const List<Color> categoryColors = [
    Color(0xFFC87941),
    Color(0xFF5B8C5A),
    Color(0xFFC2665A),
    Color(0xFFD4A05A),
    Color(0xFF7A8B6F),
    Color(0xFFB07A5B),
    Color(0xFF8B6F7A),
    Color(0xFF6F8B8A),
    Color(0xFFCBA882),
    Color(0xFF8A6E5E),
    Color(0xFF6B8E6B),
    Color(0xFF9E7B6B),
    Color(0xFFB8956A),
    Color(0xFF7B9E8C),
  ];
}
