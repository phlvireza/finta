import 'dart:math' as math;
import 'dart:ui';

/// Geometry for one donut slice's outside percentage callout — the rim
/// point the arrow starts at, the elbow where it turns horizontal, and
/// where the "42%" label sits.
class PieLabelSlot {
  /// Index into the original `values` list, so callers can pair a slot
  /// back up with its color and category.
  final int index;

  /// Point on the donut's outer edge the leader line points at.
  final Offset anchor;

  /// Where the line turns from radial to horizontal.
  final Offset elbow;

  /// End of the horizontal run — the label attaches here.
  final Offset labelAnchor;

  /// Which side of the chart the label sits on. Text is left-aligned on
  /// the right side and right-aligned on the left.
  final bool isRight;

  /// Share of the total, 0-100.
  final double percent;

  const PieLabelSlot({
    required this.index,
    required this.anchor,
    required this.elbow,
    required this.labelAnchor,
    required this.isRight,
    required this.percent,
  });
}

/// Places outside percentage labels for a donut chart and routes their
/// leader lines/arrows.
///
/// Percent-only labels ("42%") rather than the name-plus-percent labels an
/// earlier pass tried: a name needs 30px of vertical shelf per slice and a
/// wide horizontal run to avoid mid-word ellipsis, so a chart with several
/// small categories had to drop some labels outright rather than let them
/// collide. "42%" is four characters at most — every slice can afford one,
/// which is what actually answers "how much is each slice" for every
/// category rather than only the largest few. The category name itself
/// lives in the legend below the chart instead, matched by the same color.
///
/// The hard part is that slice mid-angles cluster: several thin slices in
/// a row all want a label within a few pixels of each other. So labels are
/// placed at their ideal y, then spread apart until each has [labelHeight]
/// to itself, then pulled back inside the canvas — in that order, because
/// clamping first would just re-create the overlaps.
///
/// Pure geometry, no Flutter — [Offset] and [Size] come from `dart:ui`.
///
/// [values] are raw magnitudes; they need not sum to anything in
/// particular. [radius] is the donut's outer radius. [startDegreeOffset]
/// matches fl_chart's parameter of the same name (-90 puts the first slice
/// at 12 o'clock). [gutter] is the horizontal distance from the rim to the
/// label shelf. Slices below [minSharePercent] get no slot — a callout for
/// a 0.5% sliver costs more room than it repays, and the legend below
/// still names and quantifies it.
List<PieLabelSlot> layoutPieLabels({
  required List<double> values,
  required Size size,
  required double radius,
  required double startDegreeOffset,
  required double labelHeight,
  required double gutter,
  double minSharePercent = 1.5,
}) {
  final total = values.fold<double>(0, (sum, v) => sum + (v > 0 ? v : 0));
  if (values.isEmpty || total <= 0 || size.isEmpty) return const [];

  final center = Offset(size.width / 2, size.height / 2);

  // Walk the slices in draw order, accumulating angle, and keep the ones
  // big enough to label. Sides are split by which half the mid-angle falls
  // in, so a label never has to cross the donut to reach its slice.
  final right = <_Candidate>[];
  final left = <_Candidate>[];
  var sweepSoFar = 0.0;

  for (var i = 0; i < values.length; i++) {
    final value = values[i] > 0 ? values[i] : 0.0;
    final sweep = value / total * 360;
    final midDegrees = startDegreeOffset + sweepSoFar + sweep / 2;
    sweepSoFar += sweep;

    final percent = value / total * 100;
    if (percent < minSharePercent) continue;

    final radians = midDegrees * math.pi / 180;
    final dx = math.cos(radians);
    final dy = math.sin(radians);
    final anchor = center + Offset(dx * radius, dy * radius);

    final candidate = _Candidate(
      index: i,
      anchor: anchor,
      idealY: anchor.dy,
      percent: percent,
      isRight: dx >= 0,
    );
    (candidate.isRight ? right : left).add(candidate);
  }

  final slots = <PieLabelSlot>[];
  for (final side in [right, left]) {
    if (side.isEmpty) continue;
    side.sort((a, b) => a.idealY.compareTo(b.idealY));
    _resolveOverlaps(side, labelHeight, size.height);

    for (final candidate in side) {
      final shelfX = candidate.isRight
          ? center.dx + radius + gutter
          : center.dx - radius - gutter;
      final edgeX = candidate.isRight ? size.width : 0.0;

      slots.add(PieLabelSlot(
        index: candidate.index,
        anchor: candidate.anchor,
        elbow: Offset(shelfX, candidate.placedY),
        labelAnchor: Offset(edgeX, candidate.placedY),
        isRight: candidate.isRight,
        percent: candidate.percent,
      ));
    }
  }

  return slots;
}

/// Pushes labels apart to [labelHeight] spacing, then back inside
/// `[0, height]`.
///
/// Two passes in opposite directions: the downward pass guarantees the
/// spacing but can run the last label off the bottom, and the upward pass
/// puts it back — which is why it only ever moves a label up, never
/// re-opening a gap the first pass closed.
void _resolveOverlaps(List<_Candidate> side, double labelHeight, double height) {
  final half = labelHeight / 2;

  var cursor = half;
  for (final candidate in side) {
    candidate.placedY = math.max(candidate.idealY, cursor);
    cursor = candidate.placedY + labelHeight;
  }

  // Anything that overflowed the bottom gets walked back up, carrying its
  // neighbours with it.
  cursor = height - half;
  for (final candidate in side.reversed) {
    if (candidate.placedY > cursor) candidate.placedY = cursor;
    cursor = candidate.placedY - labelHeight;
  }

  // A canvas too short to hold every label at full spacing would have the
  // walk-up push the top ones off-screen; clamp so nothing is lost even
  // then, accepting overlap as the lesser failure.
  for (final candidate in side) {
    candidate.placedY = candidate.placedY.clamp(half, math.max(half, height - half));
  }
}

class _Candidate {
  final int index;
  final Offset anchor;
  final double idealY;
  final double percent;
  final bool isRight;
  double placedY = 0;

  _Candidate({
    required this.index,
    required this.anchor,
    required this.idealY,
    required this.percent,
    required this.isRight,
  });
}
