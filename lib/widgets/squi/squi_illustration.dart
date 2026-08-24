import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/squi.dart';

class SquiIllustration extends StatefulWidget {
  final SquiPose pose;
  final double size;
  final bool backdrop;
  final bool animateEntrance;

  const SquiIllustration({
    super.key,
    required this.pose,
    required this.size,
    this.backdrop = false,
    this.animateEntrance = false,
  });

  @override
  State<SquiIllustration> createState() => _SquiIllustrationState();
}

class _SquiIllustrationState extends State<SquiIllustration> {
  var _entered = false;

  @override
  void initState() {
    super.initState();
    if (widget.animateEntrance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _entered = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    Widget image = Image.asset(
      widget.pose.asset,
      height: widget.size,
      cacheHeight: (widget.size * devicePixelRatio).round(),
      excludeFromSemantics: true,
      fit: BoxFit.contain,
    );

    if (widget.backdrop) {
      image = Container(
        width: widget.size,
        height: widget.size,
        padding: const EdgeInsets.all(AppConstants.spacingXs),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        ),
        child: image,
      );
    }

    if (!widget.animateEntrance) return image;
    return AnimatedScale(
      scale: _entered ? 1 : 0.9,
      duration: AppConstants.animNormal,
      curve: Curves.easeOut,
      child: image,
    );
  }
}
