import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Finta typography — Inter font family with warm, readable sizing.
///
/// Inter is bundled from `assets/fonts/` rather than fetched at runtime. The
/// app previously used `google_fonts`, which downloads over HTTP on first
/// launch: that made the release build — which declares no INTERNET permission
/// — silently fall back to the platform font, and it contradicted the promise
/// that the app cannot talk to the network at all. Only w400/w500/w600/w700
/// are shipped, which is exactly what the styles below use.
class AppTypography {
  AppTypography._();

  // ── Base Text Theme (Light) ─────────────────────────────────
  static TextTheme get lightTextTheme => _buildTextTheme(
        textColor: AppColors.lightTextPrimary,
        secondaryColor: AppColors.lightTextSecondary,
      );

  // ── Base Text Theme (Dark) ──────────────────────────────────
  static TextTheme get darkTextTheme => _buildTextTheme(
        textColor: AppColors.darkTextPrimary,
        secondaryColor: AppColors.darkTextSecondary,
      );

  static TextTheme _buildTextTheme({
    required Color textColor,
    required Color secondaryColor,
  }) {
    return TextTheme(
      // Balance display — large, bold
      displayLarge: _inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.5,
      ),
      // Section headings
      headlineMedium: _inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      // Card titles
      headlineSmall: _inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      // Subheadings
      titleLarge: _inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      // List item titles
      titleMedium: _inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      // Small titles
      titleSmall: _inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      // Body text
      bodyLarge: _inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      // Secondary body text
      bodyMedium: _inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      // Small body
      bodySmall: _inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      // Labels
      labelLarge: _inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      // Small labels / captions
      labelMedium: _inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      // Tiny labels
      labelSmall: _inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  /// The bundled family name, matching the `fonts:` entry in pubspec.yaml.
  static const String fontFamily = 'Inter';

  static TextStyle _inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: fontFeatures,
    );
  }

  /// Tabular (monospaced) number style for aligned amounts in lists.
  static TextStyle amountStyle({
    required Color color,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return _inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
