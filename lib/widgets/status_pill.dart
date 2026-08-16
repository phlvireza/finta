import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// A small tinted badge for a status word or a comparison figure — the
/// "+12% vs last period" / "In progress" pill shape repeated across
/// analytics and recap screens, each previously hand-rolled with its own
/// `padding: symmetric(12, 6)` + `circular(16)` literals.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
