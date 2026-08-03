import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// Layout scaffold for the app's long bottom-sheet forms — budget,
/// category, quick add.
///
/// Each of those used to be one tall `SingleChildScrollView` with the save
/// button as its last child, so on a phone (and especially with the
/// keyboard up) the primary action sat below the fold and fields near the
/// bottom of the form looked like they simply weren't there. Here the
/// header and the action are pinned and only [body] scrolls, so the button
/// is always reachable no matter how much the form grows.
///
/// The keyboard inset is applied *once*, here — callers must not wrap the
/// sheet in another `viewInsets.bottom` padding (doing so both doubles the
/// offset and, when read from the launching screen's context, never
/// updates as the keyboard opens).
class FormSheet extends StatelessWidget {
  final String title;

  /// Optional trailing action in the header row, e.g. "save as template".
  final Widget? headerAction;

  /// Scrolling content between the header and the pinned [action].
  final Widget body;

  /// Pinned footer, typically the submit button.
  final Widget? action;

  /// Fraction of the screen the sheet may grow to before [body] scrolls.
  final double maxHeightFactor;

  const FormSheet({
    super.key,
    required this.title,
    required this.body,
    this.headerAction,
    this.action,
    this.maxHeightFactor = 0.9,
  });

  /// Opens [builder]'s sheet with the settings [FormSheet] expects.
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
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: body,
                ),
              ),
              if (action != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spacingLg,
                    AppConstants.spacingMd,
                    AppConstants.spacingLg,
                    AppConstants.spacingLg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: action,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
