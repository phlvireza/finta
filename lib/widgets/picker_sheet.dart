import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import 'sheet_shell.dart';

/// Bottom sheet for picking one item out of a list — the category picker,
/// the bulk recategorize sheet.
///
/// The list is the flexible child, so it takes whatever height is left under
/// [SheetShell]'s cap: with a [pinnedHeader] search field focused, the
/// keyboard shrinks the list instead of pushing the sheet off the top of the
/// screen.
class PickerSheet extends StatelessWidget {
  final String title;

  /// Optional pinned row between the title and the list, typically a search
  /// field. Stays put while [children] scroll under it.
  final Widget? pinnedHeader;

  /// Rows of the picker, usually `ListTile`s.
  final List<Widget> children;

  /// Shown in place of the list when [children] is empty.
  final Widget? emptyState;

  final double maxHeightFactor;

  const PickerSheet({
    super.key,
    required this.title,
    required this.children,
    this.pinnedHeader,
    this.emptyState,
    this.maxHeightFactor = 0.9,
  });

  /// Opens [builder]'s sheet with the settings [PickerSheet] expects.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return SheetShell.show<T>(context, builder: builder);
  }

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      title: title,
      maxHeightFactor: maxHeightFactor,
      children: [
        if (pinnedHeader != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              0,
              AppConstants.spacingLg,
              AppConstants.spacingMd,
            ),
            child: pinnedHeader,
          ),
        Flexible(
          child: children.isEmpty && emptyState != null
              ? Center(child: emptyState)
              : ListView(
                  padding: EdgeInsets.zero,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  shrinkWrap: true,
                  children: children,
                ),
        ),
      ],
    );
  }
}
