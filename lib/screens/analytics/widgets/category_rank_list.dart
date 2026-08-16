import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/category_color.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/constants/app_typography.dart';
import '../../../l10n/app_localizations.dart';

/// Ranked list of categories with percentage bars in each category's own
/// colour. Caps at 5 rows with a "Show all (N)" expander rather than
/// silently truncating — a user with 12 categories could otherwise never
/// see the last 7 with no indication they exist.
class CategoryRankList extends StatefulWidget {
  final List<CategoryAnalytics> data;

  const CategoryRankList({super.key, required this.data});

  @override
  State<CategoryRankList> createState() => _CategoryRankListState();
}

class _CategoryRankListState extends State<CategoryRankList> {
  static const _collapsedCount = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final data = widget.data;
    final displayData = _expanded ? data : data.take(_collapsedCount).toList();

    return Column(
      children: [
      ...List.generate(displayData.length, (i) {
        final item = displayData[i];
        final category = categories.getCategoryById(item.categoryId);

        if (category == null) return const SizedBox.shrink();

        // The category's own colour, not a by-rank slot off the chart ramp:
        // a user who recolours a category expects to find it wearing that
        // colour here, and this row already shows the category's icon and
        // name, so it was the one place the two openly disagreed.
        final color = resolveCategoryColor(category.color, isDark: isDark);

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            0,
            AppConstants.spacingLg,
            AppConstants.spacingMd,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(category.iconData, size: 20, color: color),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              // Details & Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(category.name, style: theme.textTheme.titleSmall),
                        Text(
                          NumberUtils.formatCurrency(
                            item.total,
                            symbol: settings.currencySymbol,
                            useDecimals: settings.currencyUseDecimals,
                          ),
                          style: AppTypography.amountStyle(
                            color: theme.textTheme.bodyLarge!.color!,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingXs),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: item.percentage,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingMd),
                        SizedBox(
                          width: 40,
                          child: Text(
                            NumberUtils.formatPercentage(item.percentage),
                            style: theme.textTheme.labelSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
        if (!_expanded && data.length > _collapsedCount)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = true),
                child: Text(loc.showAllCount(data.length)),
              ),
            ),
          ),
      ],
    );
  }
}
