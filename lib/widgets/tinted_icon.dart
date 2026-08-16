import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// The rounded-square "identity chip" repeated across the app — an icon at
/// full-strength [color] on a [color] fill at 12% alpha. Was previously
/// hand-rolled at four different sizes (32/40/44/48) and five different
/// alphas (0.08/0.1/0.12/0.14/0.15) depending on the screen; this is the one
/// version, with [compact] as the only size variant.
class TintedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool compact;

  const TintedIcon({
    super.key,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 40.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Icon(icon, size: compact ? 16 : 20, color: color),
    );
  }
}
