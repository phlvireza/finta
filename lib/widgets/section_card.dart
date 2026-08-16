import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// The app's one grouping container — surface fill, 1px outline border,
/// `radiusMd` corners, zero elevation. This is the recipe six different
/// screens had each hand-rolled as a private `_XCard` class; consolidating
/// it here means a single row inside one budget, or one goal, or one
/// settings group all read as the same kind of thing.
///
/// [title] renders as a header row inside the card (with optional
/// [trailing]) rather than as a sibling `Text` above it — grouping the
/// heading with the content it labels is the main visual change this widget
/// makes across the app.
///
/// [padding] applies to the **body only**. The header keeps its own inset
/// either way — callers pass `EdgeInsets.zero` so `ListTile` rows can run
/// edge to edge, and before this the title went with them and ended up
/// pressed against the card border.
///
/// [clipBehavior] defaults to [Clip.antiAlias] so a `Slidable` action pane
/// hosted inside a card is clipped to the rounded corners instead of
/// bleeding past them.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppConstants.spacingMd),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasHeader = title != null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasHeader)
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: Text(title!, style: theme.textTheme.titleMedium),
                ),
                // Without this the title's last glyph and the trailing
                // value's first one abut — visible wherever both are long,
                // e.g. "Net Worth" against a full currency amount.
                if (trailing != null) const SizedBox(width: AppConstants.spacingMd),
                ?trailing,
              ],
            ),
          ),
        Padding(
          // The header already supplied the top inset, so zero it here or
          // the gap under the title doubles.
          padding: hasHeader ? padding.copyWith(top: 0) : padding,
          child: child,
        ),
      ],
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
