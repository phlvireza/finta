// Picks a font size for the big amount field so the *whole* amount stays
// visible instead of scrolling out of the row.
//
// The field renders at a fixed 48px by default, which only fits ~7
// characters once the currency symbol and calculator button have taken
// their share of a phone-width row. Anything longer used to scroll
// horizontally inside the TextField, hiding the leading digits behind the
// currency symbol — so `Rp 1,500,000` read as `500,000`.
//
// Kept as a pure function (no Flutter import) so the sizing rule is
// unit-testable without a widget tree.

/// Advance width of one character as a fraction of the font size.
///
/// The amount style uses Inter with [FontFeature.tabularFigures], so every
/// digit is the same width — 0.62 is that advance rounded *up*, and commas
/// and dots are narrower still. Erring high means the estimate never
/// under-shrinks, which is the failure that clips text.
const double _defaultCharWidthFactor = 0.62;

/// Largest font size at which [characterCount] characters still fit inside
/// [maxWidth], clamped to `[minFontSize, maxFontSize]`.
///
/// An empty field keeps [maxFontSize] — there is nothing to shrink, and the
/// `0` hint should still be full size.
double fitAmountFontSize({
  required int characterCount,
  required double maxWidth,
  double maxFontSize = 48,
  double minFontSize = 16,
  double charWidthFactor = _defaultCharWidthFactor,
}) {
  if (characterCount <= 0 || maxWidth <= 0) return maxFontSize;

  final fitted = maxWidth / (characterCount * charWidthFactor);
  if (fitted >= maxFontSize) return maxFontSize;
  if (fitted <= minFontSize) return minFontSize;
  return fitted;
}
