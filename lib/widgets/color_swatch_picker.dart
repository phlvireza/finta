import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// Horizontal row of colour swatches used by the account, category and goal
/// forms to pick an entity's accent colour.
///
/// The three forms each carried their own copy of this list, and the copies
/// had already drifted: the goal form hard-coded a private ten-colour palette
/// while the other two read [AppColors.swatchOptions], so editing the app
/// palette silently missed goals.
class ColorSwatchPicker extends StatelessWidget {
  /// Currently selected colour, as a `#RRGGBB` string.
  final String selected;

  final ValueChanged<String> onChanged;

  /// Defaults to [AppColors.swatchOptions]; overridable mainly for tests.
  final List<String> options;

  const ColorSwatchPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.options = AppColors.swatchOptions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A row saved before the palette changed — or under the goal form's old
    // private palette — holds a hex that is no longer an option. Showing it
    // anyway keeps it selected while editing, instead of presenting the form
    // with nothing highlighted and silently rewriting the colour on save.
    final swatches = options.contains(selected)
        ? options
        : [selected, ...options];

    return SizedBox(
      height: _swatchSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: swatches.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppConstants.spacingMd),
        itemBuilder: (context, index) {
          final hex = swatches[index];
          final isSelected = hex == selected;

          return GestureDetector(
            onTap: () => onChanged(hex),
            child: Container(
              width: _swatchSize,
              decoration: BoxDecoration(
                color: _parseHex(hex, fallback: theme.colorScheme.surface),
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(
                        color: theme.colorScheme.onSurface,
                        width: _selectedBorderWidth,
                      )
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

const double _swatchSize = 48.0;
const double _selectedBorderWidth = 3.0;

/// `int.tryParse`, not `int.parse`: the forms used to parse straight into
/// `Color(int.parse(...))`, which throws a `FormatException` mid-build on a
/// malformed stored hex and takes the whole form down. A wrong swatch colour
/// is a much better failure than a form that won't open.
Color _parseHex(String hex, {required Color fallback}) {
  final digits = hex.replaceAll('#', '');
  if (digits.length != 6) return fallback;
  final value = int.tryParse(digits, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
