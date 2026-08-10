import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/pie_label_layout.dart';

const _size = Size(360, 300);
const _radius = 80.0;
const _labelHeight = 22.0;
const _gutter = 10.0;

List<PieLabelSlot> layout(
  List<double> values, {
  Size size = _size,
  double minSharePercent = 1.5,
  double startDegreeOffset = -90,
}) {
  return layoutPieLabels(
    values: values,
    size: size,
    radius: _radius,
    startDegreeOffset: startDegreeOffset,
    labelHeight: _labelHeight,
    gutter: _gutter,
    minSharePercent: minSharePercent,
  );
}

void main() {
  group('degenerate input', () {
    test('no values produces no slots', () {
      expect(layout(const []), isEmpty);
    });

    test('all-zero values produce no slots', () {
      expect(layout([0, 0, 0]), isEmpty);
    });

    test('an empty canvas produces no slots', () {
      expect(layout([1, 1], size: Size.zero), isEmpty);
    });

    test('negative values are treated as zero rather than skewing the total', () {
      final slots = layout([100, -50]);
      expect(slots.map((s) => s.index), [0]);
      expect(slots.single.percent, closeTo(100, 0.01));
    });
  });

  group('percentages', () {
    test('are the slice share of the total', () {
      final slots = layout([50, 30, 20]);
      expect(slots.firstWhere((s) => s.index == 0).percent, closeTo(50, 0.01));
      expect(slots.firstWhere((s) => s.index == 1).percent, closeTo(30, 0.01));
      expect(slots.firstWhere((s) => s.index == 2).percent, closeTo(20, 0.01));
    });

    test('slices under the threshold get no slot', () {
      // 1% and 0.5% fall under the default 1.5% floor.
      final slots = layout([100, 1, 0.5, 50]);
      expect(slots.map((s) => s.index), unorderedEquals([0, 3]));
    });

    test('the threshold can be lowered to include everything', () {
      final slots = layout([100, 1, 0.5, 50], minSharePercent: 0);
      expect(slots.map((s) => s.index), unorderedEquals([0, 1, 2, 3]));
    });

    test('a single slice is placed', () {
      final slots = layout([42]);
      expect(slots, hasLength(1));
      expect(slots.single.percent, closeTo(100, 0.01));
    });
  });

  group('side assignment', () {
    // With startDegreeOffset -90 the first slice starts at 12 o'clock and
    // sweeps clockwise, so a leading half goes down the right-hand side.
    test('the first half of the ring lands on the right', () {
      final slots = layout([50, 50]);
      expect(slots.firstWhere((s) => s.index == 0).isRight, isTrue);
      expect(slots.firstWhere((s) => s.index == 1).isRight, isFalse);
    });

    test('right-side labels sit right of centre, left-side labels left', () {
      final slots = layout([50, 50]);
      for (final slot in slots) {
        if (slot.isRight) {
          expect(slot.elbow.dx, greaterThan(_size.width / 2));
          expect(slot.labelAnchor.dx, _size.width);
        } else {
          expect(slot.elbow.dx, lessThan(_size.width / 2));
          expect(slot.labelAnchor.dx, 0);
        }
      }
    });

    test('the elbow sits one gutter beyond the rim', () {
      final slots = layout([50, 50]);
      final right = slots.firstWhere((s) => s.isRight);
      expect(right.elbow.dx, closeTo(_size.width / 2 + _radius + _gutter, 0.01));
    });

    test('anchors land on the rim', () {
      final slots = layout([25, 25, 25, 25]);
      final center = Offset(_size.width / 2, _size.height / 2);
      for (final slot in slots) {
        expect((slot.anchor - center).distance, closeTo(_radius, 0.01));
      }
    });
  });

  group('collision resolution', () {
    test('labels on a side are at least labelHeight apart', () {
      // Eight equal slices put four labels on each side, several of them
      // wanting almost the same y.
      final slots = layout(List.filled(8, 1.0));

      for (final isRight in [true, false]) {
        final ys = slots.where((s) => s.isRight == isRight).map((s) => s.elbow.dy).toList()
          ..sort();
        for (var i = 1; i < ys.length; i++) {
          expect(
            ys[i] - ys[i - 1],
            greaterThanOrEqualTo(_labelHeight - 0.01),
            reason: 'labels on the ${isRight ? 'right' : 'left'} overlap',
          );
        }
      }
    });

    test('many thin slices stay inside the canvas', () {
      final slots = layout(List.filled(16, 1.0), minSharePercent: 0);
      expect(slots, hasLength(16));
      for (final slot in slots) {
        expect(slot.elbow.dy, greaterThanOrEqualTo(_labelHeight / 2 - 0.01));
        expect(slot.elbow.dy, lessThanOrEqualTo(_size.height - _labelHeight / 2 + 0.01));
      }
    });

    test('a short canvas still keeps every label on screen', () {
      // Room for ~4 labels per side but 5 asking for space — overlap is
      // acceptable here, labels escaping the canvas is not.
      final slots = layout(List.filled(10, 1.0), size: const Size(360, 100));
      expect(slots, hasLength(10));
      for (final slot in slots) {
        expect(slot.elbow.dy, greaterThanOrEqualTo(0));
        expect(slot.elbow.dy, lessThanOrEqualTo(100));
      }
    });

    test('ordering down a side follows the ring, not the input order', () {
      final slots = layout(List.filled(8, 1.0));
      final right = slots.where((s) => s.isRight).toList()
        ..sort((a, b) => a.elbow.dy.compareTo(b.elbow.dy));
      // Clockwise from 12 o'clock, so earlier slices sit higher.
      expect(right.map((s) => s.index), orderedEquals(right.map((s) => s.index).toList()..sort()));
    });

    test('the label anchor shares the elbow y so the run is horizontal', () {
      final slots = layout(List.filled(6, 1.0));
      for (final slot in slots) {
        expect(slot.labelAnchor.dy, slot.elbow.dy);
      }
    });
  });
}
