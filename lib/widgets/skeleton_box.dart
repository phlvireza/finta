import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// A shimmering placeholder rectangle — the building block for
/// content-shaped loading states. Preserves the shape of the screen
/// while data loads, instead of a centred spinner that reads as a stall
/// on a data-dense screen.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.5 + (_controller.value * 0.3)),
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(AppConstants.radiusSm),
          ),
        );
      },
    );
  }
}

/// A row-shaped placeholder matching TransactionTile's layout — an icon
/// circle plus two text lines and a trailing amount box.
class SkeletonTransactionRow extends StatelessWidget {
  const SkeletonTransactionRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingMd,
        horizontal: AppConstants.spacingLg,
      ),
      child: Row(
        children: [
          SkeletonBox(
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 140, height: 14),
                const SizedBox(height: AppConstants.spacingXs),
                SkeletonBox(width: 90, height: 12),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          const SkeletonBox(width: 60, height: 14),
        ],
      ),
    );
  }
}

/// A list of skeleton rows, for a full-screen loading state.
class SkeletonTransactionList extends StatelessWidget {
  final int count;

  const SkeletonTransactionList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (context, index) => const SkeletonTransactionRow(),
    );
  }
}

/// Placeholder matching the Analytics tab's shape — a donut chart circle
/// above a handful of ranked-category bars.
class SkeletonAnalytics extends StatelessWidget {
  const SkeletonAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      children: [
        Center(
          child: SkeletonBox(
            width: 200,
            height: 200,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        const SizedBox(height: AppConstants.spacingXxxl),
        for (var i = 0; i < 4; i++) ...[
          Row(
            children: [
              SkeletonBox(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(child: SkeletonBox(height: 14)),
            ],
          ),
          const SizedBox(height: AppConstants.spacingLg),
        ],
      ],
    );
  }
}
