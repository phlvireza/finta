import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/squi.dart';
import 'squi_illustration.dart';

class SquiState extends StatelessWidget {
  final SquiPose pose;
  final String title;
  final String? subtitle;
  final Widget? action;

  const SquiState({
    super.key,
    required this.pose,
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
            SquiIllustration(pose: pose, size: SquiSizes.md),
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
              // Full width on the same measure onboarding uses, so an empty
              // state's call to action is the size of "Get started" rather
              // than the width of whatever its own label happens to be.
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppConstants.maxContentWidth,
                ),
                child: SizedBox(width: double.infinity, child: action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
