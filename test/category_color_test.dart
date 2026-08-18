import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/category_color.dart';
import 'package:finta/models/category_model.dart';

const _fallback = Color(0xFF123456);

CategoryModel _cat(String color) {
  return CategoryModel(
    id: 'c1',
    name: 'Food',
    type: 'expense',
    icon: 'restaurant',
    color: color,
    isDefault: false,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('resolveCategoryChartColor', () {
    test('uses the category\'s stored colour', () {
      expect(
        resolveCategoryChartColor(_cat('#3F8B4C'), fallback: _fallback),
        const Color(0xFF3F8B4C),
      );
    });

    test('accepts a hex written without the leading hash', () {
      expect(
        resolveCategoryChartColor(_cat('3F8B4C'), fallback: _fallback),
        const Color(0xFF3F8B4C),
      );
    });

    test('is case-insensitive', () {
      expect(
        resolveCategoryChartColor(_cat('#c1661e'), fallback: _fallback),
        const Color(0xFFC1661E),
      );
    });

    // A transaction can outlive the category it pointed at, so the chart
    // still has a row to draw with no category behind it.
    test('falls back when the category is missing', () {
      expect(resolveCategoryChartColor(null, fallback: _fallback), _fallback);
    });

    // The whole reason this helper exists: CategoryModel.colorValue would
    // throw here, and it is called inside CustomPainter.paint().
    test('falls back on a malformed hex instead of throwing', () {
      expect(resolveCategoryChartColor(_cat('#ZZZZZZ'), fallback: _fallback), _fallback);
      expect(resolveCategoryChartColor(_cat('not a colour'), fallback: _fallback), _fallback);
    });

    test('falls back on a hex of the wrong length', () {
      expect(resolveCategoryChartColor(_cat('#FFF'), fallback: _fallback), _fallback);
      expect(resolveCategoryChartColor(_cat('#FF3F8B4C'), fallback: _fallback), _fallback);
      expect(resolveCategoryChartColor(_cat(''), fallback: _fallback), _fallback);
    });

    test('always returns a fully opaque colour', () {
      expect(
        resolveCategoryChartColor(_cat('#000000'), fallback: _fallback),
        const Color(0xFF000000),
      );
    });
  });
}
