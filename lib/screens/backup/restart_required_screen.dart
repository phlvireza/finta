import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../l10n/app_localizations.dart';

/// Shown immediately after a successful restore. Flutter has no supported
/// way to restart its own process, so rather than fake a restart (or leave
/// stale in-memory state pointing at file handles for a database file that
/// no longer matches what's on disk), this screen blocks further use of the
/// app and tells the user to close and reopen it themselves.
class RestartRequiredScreen extends StatelessWidget {
  const RestartRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingXxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: AppConstants.spacingXl),
                  Text(
                    loc.restoreCompleteTitle,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    loc.restoreCompleteMessage,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
