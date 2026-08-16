import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/category_color.dart';

/// Horizontal strip of tappable colour circles, checkmarking the selected
/// one.
///
/// Was copy-pasted verbatim into the category form and the account form;
/// pulled out here when a third caller (the default-category colour sheet)
/// needed it too.
class ColorSwatchPicker extends StatelessWidget {
  /// Hex strings in `'#RRGGBB'` form — the format the `color` column stores,
  /// so [selected] can be compared without parsing.
  final List<String> options;

  final String selected;
  final ValueChanged<String> onSelected;

  const ColorSwatchPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A colour that predates the current swatch list (or came from a
    // restored backup) would otherwise be missing from the strip entirely,
    // so the row would render with nothing checked and the user would have
    // no way back to what they already had. Show it first instead.
    final swatches = options.contains(selected) ? options : [selected, ...options];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: swatches.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppConstants.spacingMd),
        itemBuilder: (context, index) {
          final hex = swatches[index];
          final color = parseHexColor(hex);
          final isSelected = hex == selected;

          return GestureDetector(
            onTap: () => onSelected(hex),
            child: Container(
              width: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                    : null,
              ),
              // The checkmark used to be hardcoded white, which all but
              // disappeared on the lighter swatches. Same brightness
              // estimate the spending heatmap uses for its cell labels.
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
