import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'error_state.dart';

/// A committed transaction must never return to a form that can post it again.
/// This callback only refreshes state and completes navigation.
class TransactionSaveRecovery extends StatefulWidget {
  final Future<void> Function() onRetry;

  const TransactionSaveRecovery({super.key, required this.onRetry});

  @override
  State<TransactionSaveRecovery> createState() =>
      _TransactionSaveRecoveryState();
}

class _TransactionSaveRecoveryState extends State<TransactionSaveRecovery> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRetry();
    } catch (_) {
      // Keep the saved confirmation and allow another refresh attempt.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return _busy
        ? const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        : ErrorState(
            title: loc.transactionSaved,
            message: loc.savedRefreshFailed,
            onRetry: _retry,
          );
  }
}
