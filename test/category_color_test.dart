import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finta/core/constants/app_colors.dart';
import 'package:finta/core/utils/category_color.dart';

void main() {
  group('parseHexColor', () {
    test('parses the stored #RRGGBB form at full opacity', () {
      expect(parseHexColor('#3F8B4C'), const Color(0xFF3F8B4C));
    });

    test('parses a hex with no leading hash', () {
      expect(parseHexColor('3F8B4C'), const Color(0xFF3F8B4C));
    });

    test('is case insensitive', () {
      expect(parseHexColor('#3f8b4c'), const Color(0xFF3F8B4C));
    });

    test('falls back instead of throwing on a truncated value', () {
      expect(parseHexColor('#3F8B', fallback: const Color(0xFF000001)),
          const Color(0xFF000001));
    });

    test('falls back instead of throwing on a non-hex value', () {
      expect(parseHexColor('#ZZZZZZ', fallback: const Color(0xFF000001)),
          const Color(0xFF000001));
    });

    test('falls back on an empty string', () {
      expect(parseHexColor('', fallback: const Color(0xFF000001)),
          const Color(0xFF000001));
    });
  });

  group('resolveCategoryColor', () {
    test('light mode paints the stored hex verbatim', () {
      for (final hex in AppColors.swatchOptions) {
        expect(
          resolveCategoryColor(hex, isDark: false),
          parseHexColor(hex),
          reason: '$hex should not be re-mapped in light mode',
        );
      }
    });

    test('dark mode swaps a light ramp hue for its dark counterpart', () {
      // Green: the light ramp's #3F8B4C becomes the dark ramp's #4F9E4F.
      expect(
        resolveCategoryColor('#3F8B4C', isDark: true),
        const Color(0xFF4F9E4F),
      );
      expect(
        resolveCategoryColor('#2E5FA8', isDark: true),
        const Color(0xFF4779C4),
      );
    });

    test('dark mode matches a stored hex case insensitively', () {
      expect(
        resolveCategoryColor('#3f8b4c', isDark: true),
        const Color(0xFF4F9E4F),
      );
    });

    test('a non-ramp swatch is painted verbatim in dark mode too', () {
      // The earth tones in swatchOptions have no dark-ramp twin — they are
      // mid-toned enough to read on either surface, and inventing one would
      // mean shipping a hue the palette validator never checked.
      expect(resolveCategoryColor('#C87941', isDark: true), const Color(0xFFC87941));
      expect(resolveCategoryColor('#8A7E74', isDark: true), const Color(0xFF8A7E74));
    });

    test('an unparseable stored colour still resolves to the fallback', () {
      expect(resolveCategoryColor('nonsense', isDark: false), const Color(0xFF8A7E74));
      expect(resolveCategoryColor('nonsense', isDark: true), const Color(0xFF8A7E74));
    });
  });

  group('darkRampTwins', () {
    // AppColors calls the ramps' order load-bearing. This table pairs them by
    // index, so reordering or re-hexing a hue without updating it would
    // silently start painting the wrong dark-mode colour.
    test('pairs every light ramp hue with the dark hue at the same index', () {
      expect(darkRampTwins.length, AppColors.chartColorsLight.length);

      for (var i = 0; i < AppColors.chartColorsLight.length; i++) {
        final entry = darkRampTwins.entries.firstWhere(
          (e) => parseHexColor(e.key) == AppColors.chartColorsLight[i],
          orElse: () =>
              throw TestFailure('no dark twin keyed on ramp index $i'),
        );

        expect(
          parseHexColor(entry.value),
          AppColors.chartColorsDark[i],
          reason: 'ramp index $i maps to the wrong dark hue',
        );
      }
    });

    test('every key is a colour the picker can actually offer', () {
      for (final key in darkRampTwins.keys) {
        expect(AppColors.swatchOptions, contains(key));
      }
    });
  });
}
