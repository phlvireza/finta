import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/category_color.dart';
import '../../../core/utils/number_utils.dart';
import '../../../core/utils/pie_label_layout.dart';
import '../../../l10n/app_localizations.dart';

/// Radius of the donut ring itself.
const double _ringRadius = 46;

/// Hole in the middle, which the total sits in.
const double _centerRadius = 50;

/// Distance from the rim to the vertical shelf the percentage labels line
/// up on.
const double _labelGutter = 10;

/// Vertical space each percentage label reserves.
const double _labelHeight = 22;

/// Donut chart showing breakdown of spending/income by category, with an
/// outside percentage callout per slice and a color-key legend underneath.
///
/// Two passes came before this one. The first drew percentage-only titles
/// *inside* the ring, which worked until two similar-percentage slices sat
/// next to each other with nothing to tell them apart but color — and the
/// original nine-color palette had six hues too close to gray to carry that
/// weight (see [AppColors.chartColorsLight]). The second moved to
/// name-plus-percentage labels outside the ring on leader lines, but a name
/// needs real shelf space, so charts with several small categories had to
/// drop some labels outright — exactly the "several slices have no
/// description" gap that prompted this pass.
///
/// This version separates the two jobs. The leader lines here carry only
/// the percentage — four characters at most, so every slice above
/// [layoutPieLabels]'s share floor gets one, arrow and all, pointing at
/// its exact slice. *Which* category that slice is lives in the legend
/// below instead, keyed by the same color used on the ring — a color a
/// reader only has to resolve once, in one place, rather than repeat it as
/// text next to every callout.
class BreakdownChart extends StatelessWidget {
  final List<CategoryAnalytics> data;
  final double total;

  const BreakdownChart({
    super.key,
    required this.data,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final categories = context.watch<CategoryProvider>();
    final loc = AppLocalizations.of(context)!;
    final palette = isDark ? AppColors.chartColorsDark : AppColors.chartColorsLight;

    // Resolved once and shared by the ring, the leader lines and the
    // legend, so the three can never disagree about which colour belongs
    // to which slice. Each entry is the category's own colour, with the
    // rank-indexed palette as the fallback.
    //
    // Because colours are the user's choice now, two slices can end up the
    // same hue where the old ramp guaranteed they wouldn't. `sectionsSpace`
    // below keeps them countable and the legend names them.
    final sliceColors = [
      for (var i = 0; i < data.length; i++)
        resolveCategoryChartColor(
          categories.getCategoryById(data[i].categoryId),
          fallback: palette[i % palette.length],
        ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);

              final slots = layoutPieLabels(
                values: [for (final item in data) item.total],
                size: size,
                radius: _centerRadius + _ringRadius,
                // Matches PieChartData.startDegreeOffset below — the
                // callouts have to agree with where fl_chart actually
                // drew the slices.
                startDegreeOffset: -90,
                labelHeight: _labelHeight,
                gutter: _labelGutter,
              );

              return Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: _centerRadius,
                      startDegreeOffset: -90,
                      sections: List.generate(data.length, (i) {
                        return PieChartSectionData(
                          color: sliceColors[i],
                          value: data[i].total,
                          // Drawn by the overlay instead, so the two can
                          // never disagree about placement.
                          title: '',
                          radius: _ringRadius,
                        );
                      }),
                    ),
                  ),
                  // Ignores pointers so it never eats a tap meant for the
                  // chart itself.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ArrowLabelPainter(
                          slots: slots,
                          sliceColors: sliceColors,
                          textColor: theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface,
                          textDirection: Directionality.of(context),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _centerRadius * 1.7,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(loc.chartTotal, style: theme.textTheme.labelMedium),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            NumberUtils.formatCurrency(
                              total,
                              symbol: settings.currencySymbol,
                              useDecimals: settings.currencyUseDecimals,
                            ),
                            style: AppTypography.amountStyle(
                              color: theme.textTheme.bodyLarge!.color!,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppConstants.spacingLg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppConstants.spacingMd,
          runSpacing: AppConstants.spacingSm,
          children: List.generate(data.length, (i) {
            final name = categories.getCategoryById(data[i].categoryId)?.name ?? loc.unknown;
            final percent = total > 0 ? data[i].total / total * 100 : 0.0;
            return _LegendEntry(
              color: sliceColors[i],
              name: name,
              percent: percent,
            );
          }),
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  final Color color;
  final String name;
  final double percent;

  const _LegendEntry({required this.color, required this.name, required this.percent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        // Identity lives in the dot; the label stays in the normal text
        // color rather than repeating the series color, matching every
        // other text-vs-mark pairing in the app's charts.
        Text('$name · ${percent.toStringAsFixed(0)}%', style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Draws each slice's leader line, a small arrowhead pointing at the rim,
/// and the percentage text.
///
/// Text goes through [TextPainter] rather than positioned widgets so it
/// can be measured against the exact room available between the shelf and
/// the canvas edge.
class _ArrowLabelPainter extends CustomPainter {
  final List<PieLabelSlot> slots;

  /// Already resolved per slice by the caller, indexed the same way as the
  /// chart's data. Resolving here instead would mean a category lookup
  /// inside [paint], which runs on every frame.
  final List<Color> sliceColors;

  final Color textColor;
  final TextDirection textDirection;

  _ArrowLabelPainter({
    required this.slots,
    required this.sliceColors,
    required this.textColor,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;

    for (final slot in slots) {
      final color = sliceColors[slot.index % sliceColors.length];
      linePaint.color = color.withValues(alpha: 0.75);

      final label = _buildLabel(slot);
      final textLeft = slot.isRight ? slot.elbow.dx + 6 : slot.elbow.dx - 6 - label.width;
      final lineEnd = slot.isRight ? textLeft - 3 : textLeft + label.width + 3;

      // Pull the line's start in from the rim slightly so the arrowhead —
      // drawn at the anchor — has room to sit clear of the slice edge.
      final direction = slot.anchor - Offset(size.width / 2, size.height / 2);
      final unit = direction.distance == 0 ? const Offset(0, -1) : direction / direction.distance;
      final lineStart = slot.anchor + unit * 6;

      final path = Path()
        ..moveTo(lineStart.dx, lineStart.dy)
        ..lineTo(slot.elbow.dx, slot.elbow.dy)
        ..lineTo(lineEnd, slot.elbow.dy);
      canvas.drawPath(path, linePaint);

      _drawArrowhead(canvas, slot.anchor, unit, color);

      label.paint(canvas, Offset(textLeft, slot.elbow.dy - label.height / 2));
    }
  }

  /// A small filled triangle at the rim end of the leader line, pointing
  /// into the slice it labels — the "which category is this percentage
  /// for" cue a bare line leaves the reader to guess at.
  void _drawArrowhead(Canvas canvas, Offset tip, Offset unit, Color color) {
    const length = 7.0;
    const halfWidth = 3.0;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final back = tip - unit * length;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + perpendicular.dx * halfWidth, back.dy + perpendicular.dy * halfWidth)
      ..lineTo(back.dx - perpendicular.dx * halfWidth, back.dy - perpendicular.dy * halfWidth)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  TextPainter _buildLabel(PieLabelSlot slot) {
    final painter = TextPainter(
      text: TextSpan(
        text: '${slot.percent.toStringAsFixed(0)}%',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
      textDirection: textDirection,
    )..layout();
    return painter;
  }

  @override
  bool shouldRepaint(_ArrowLabelPainter oldDelegate) {
    // sliceColors is compared by value: recolouring a category leaves the
    // data — and so the slots — identical, so without this the leader
    // lines would keep the old colour until something else forced a
    // repaint.
    return oldDelegate.slots != slots ||
        oldDelegate.textColor != textColor ||
        !listEquals(oldDelegate.sliceColors, sliceColors);
  }
}
