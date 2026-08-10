import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// Chrome shared by every titled modal bottom sheet in the app — the drag
/// handle, the pinned title row, and (the part that is easy to get wrong)
/// the sizing.
///
/// Sizing is a *cap*, never a fixed height: the sheet grows to fit its
/// content up to [maxHeightFactor] of the screen, inside the safe area, with
/// the keyboard inset applied once. A sheet that instead hard-codes
/// `SizedBox(height: 0.6 * screenHeight)` and adds `viewInsets.bottom` on top
/// is asking for a height greater than the screen the moment a keyboard
/// opens — it then gets clamped to full screen and its rounded top corners
/// are pushed up under the status bar. That was the category picker's bug.
///
/// The keyboard inset is applied *here*, once — composers and callers must
/// not wrap the sheet in another `viewInsets.bottom` padding (doing so both
/// doubles the offset and, when read from the launching screen's context,
/// never updates as the keyboard opens).
///
/// [children] are laid out in a `Column` below the header, so a child that
/// should absorb the leftover height (a scroll view, a list) must be wrapped
/// in `Flexible`. See [FormSheet] and [PickerSheet], the two compositions
/// that exist.
class SheetShell extends StatelessWidget {
  final String title;

  /// Optional trailing action in the header row, e.g. "save as template".
  final Widget? headerAction;

  /// Content below the header row.
  final List<Widget> children;

  /// Fraction of the screen the sheet may grow to before its flexible child
  /// has to scroll.
  final double maxHeightFactor;

  const SheetShell({
    super.key,
    required this.title,
    required this.children,
    this.headerAction,
    this.maxHeightFactor = 0.9,
  });

  /// Opens [builder]'s sheet with the settings a [SheetShell] expects.
  ///
  /// `useSafeArea: true` is the non-negotiable half: without it an
  /// `isScrollControlled` sheet is allowed to draw over the status bar.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppConstants.spacingSm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingLg,
                  AppConstants.spacingMd,
                  AppConstants.spacingLg,
                  AppConstants.spacingSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleLarge),
                    ),
                    ?headerAction,
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
