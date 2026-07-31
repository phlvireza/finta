import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// Wraps a formatted amount and replaces it with dots whenever
/// [SettingsProvider.hideBalances] is on — a shoulder-surfing privacy
/// toggle. Callers pass the already-formatted text; this widget only
/// decides whether to show it.
class MaskedAmount extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextOverflow? overflow;
  final int? maxLines;

  const MaskedAmount({
    super.key,
    required this.text,
    this.style,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final hide = context.select<SettingsProvider, bool>((s) => s.hideBalances);
    return Text(
      hide ? '••••••' : text,
      style: style,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}
