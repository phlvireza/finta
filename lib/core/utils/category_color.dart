import 'package:flutter/material.dart';
import '../../models/category_model.dart';

/// Resolves the colour a chart should draw a category in, falling back
/// instead of throwing.
///
/// Charts used to colour slices by rank position (`palette[i % length]`),
/// which meant recolouring a category changed its icon everywhere but left
/// the analytics screen showing the old hue. They read the category's own
/// colour now, so the two agree.
///
/// This exists rather than calling [CategoryModel.colorValue] directly
/// because that getter uses `int.parse`, which throws a `FormatException`
/// on a malformed value. A bad hex is survivable in a list tile, but the
/// donut resolves its colours inside `CustomPainter.paint()`, where an
/// exception takes down the whole analytics screen. A wrong colour is a
/// much better failure than a blank screen.
///
/// [fallback] is used when the category is missing (a transaction can
/// outlive its category) or when its stored hex is unparseable.
Color resolveCategoryChartColor(
  CategoryModel? category, {
  required Color fallback,
}) {
  if (category == null) return fallback;

  final hex = category.color.replaceAll('#', '');
  if (hex.length != 6) return fallback;

  final value = int.tryParse(hex, radix: 16);
  if (value == null) return fallback;

  return Color(0xFF000000 | value);
}
