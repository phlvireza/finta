import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// Friendly empty state placeholder — shown when a list has no data.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
              child: Icon(
                icon,
                size: 36,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppConstants.spacingXl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
