import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Fallback for a colour string that can't be parsed — the same neutral the
/// "Other" categories ship with, so a corrupt row degrades to something
/// unremarkable rather than to a blank or a jarring hue.
const Color _fallbackColor = Color(0xFF8A7E74);

/// Parse a stored `'#RRGGBB'` (or `'RRGGBB'`) colour string into a [Color].
///
/// Every colour the app writes comes from a fixed swatch list, but the value
/// is stored as free-form TEXT and is read straight into `build` methods —
/// so a hand-edited backup or a truncated row would otherwise throw a
/// [FormatException] out of a widget tree with no way to recover. Returns
/// [fallback] instead.
Color parseHexColor(String hex, {Color fallback = _fallbackColor}) {
  final digits = hex.replaceAll('#', '').trim();
  if (digits.length != 6) return fallback;
  final value = int.tryParse(digits, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}

/// The colour to paint for a category (or account, or goal) in the current
/// theme.
///
/// A category stores exactly one hex, and the picker offers light-mode
/// values — [AppColors.swatchOptions] is the light chart ramp plus a few
/// earth tones. That was harmless while the charts drew their own
/// [AppColors.chartColorsDark] ramp in dark mode and ignored the stored
/// colour entirely; now that they follow the category, painting the stored
/// light hex verbatim would hand dark mode the colours that ramp exists to
/// avoid.
///
/// So a stored hex that *is* one of the light ramp's hues is swapped for its
/// dark-ramp counterpart at the same index — the two lists share a hue order
/// on purpose, so this only re-steps lightness and chroma and never changes
/// hue family. Anything else (the earth tones, or a colour from an older
/// install) is drawn as stored.
Color resolveCategoryColor(String hex, {required bool isDark}) {
  if (!isDark) return parseHexColor(hex);
  // Normalised so a value stored without the leading hash, or in lowercase,
  // still finds its twin instead of silently falling through.
  final key = '#${hex.replaceAll('#', '').trim().toUpperCase()}';
  return parseHexColor(darkRampTwins[key] ?? hex);
}

/// Light-ramp hex → dark-ramp hex, paired by index.
///
/// Public so `test/category_color_test.dart` can assert it still agrees with
/// [AppColors.chartColorsLight] / [AppColors.chartColorsDark] — the ramps'
/// doc calls their order load-bearing, and this table silently desyncs if a
/// hue is reordered or re-hexed without updating it.
const Map<String, String> darkRampTwins = {
  '#3F8B4C': '#4F9E4F', // green
  '#7B5B9E': '#7C63B8', // mauve
  '#C13F55': '#C24F62', // rose
  '#12928C': '#14A69D', // teal
  '#A0522D': '#B36A3E', // sienna
  '#2E5FA8': '#4779C4', // blue
  '#C1661E': '#C96B2E', // terracotta
};
