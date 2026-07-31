import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Finta typography — Inter font family with warm, readable sizing.
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
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.5,
      ),
      // Section headings
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      // Card titles
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      // Subheadings
      titleLarge: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      // List item titles
      titleMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      // Small titles
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      // Body text
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      // Secondary body text
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      // Small body
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      // Small labels / captions
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      // Tiny labels
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Tabular (monospaced) number style for aligned amounts in lists.
  static TextStyle amountStyle({
    required Color color,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
