import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// Reusable confirmation dialog for destructive actions (delete, etc.).
class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final Color? confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Delete',
    this.cancelText = 'Cancel',
    this.confirmColor,
  });

  /// Show the dialog and return true if confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Delete',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dangerColor = confirmColor ?? theme.colorScheme.error;

    return AlertDialog(
      title: Text(title),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        0,
        AppConstants.spacingLg,
        AppConstants.spacingMd,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: dangerColor,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
