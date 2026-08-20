import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/app_lock_policy.dart';

/// Fixed instants throughout — the policy's whole job is arithmetic on a clock
/// it was handed, so letting a real clock in would only make it flaky.
final _backgrounded = DateTime.utc(2026, 3, 14, 9, 0, 0);

void main() {
  group('autoLockTimeout', () {
    test('never maps to null, not to zero', () {
      // The two are opposites: null means "no timer at all", zero means
      // "lock the instant you leave". Conflating them turns the most
      // permissive setting into the strictest.
      expect(autoLockTimeout(autoLockNever), isNull);
      expect(autoLockTimeout(autoLockImmediately), Duration.zero);
    });

    test('a positive setting maps to that many minutes', () {
      expect(autoLockTimeout(1), const Duration(minutes: 1));
      expect(autoLockTimeout(5), const Duration(minutes: 5));
      expect(autoLockTimeout(15), const Duration(minutes: 15));
    });

    test('an unrecognized negative setting is treated as immediately', () {
      // Fail closed on a value no version of the app writes — a corrupted
      // preference should not silently disable the lock.
      expect(autoLockTimeout(-99), Duration.zero);
    });
  });

  group('shouldLock', () {
    test('does not lock when nothing was ever backgrounded', () {
      expect(
        shouldLock(
          backgroundedAt: null,
          now: _backgrounded,
          timeout: const Duration(minutes: 5),
        ),
        isFalse,
      );
    });

    test('never setting does not lock even after years in the background', () {
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded.add(const Duration(days: 3650)),
          timeout: null,
        ),
        isFalse,
      );
    });

    test('immediately locks with no time elapsed at all', () {
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded,
          timeout: Duration.zero,
        ),
        isTrue,
      );
    });

    test('immediately locks even when the clock ran backwards', () {
      // Answered before any subtraction, so there is nothing to tamper with.
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded.subtract(const Duration(hours: 1)),
          timeout: Duration.zero,
        ),
        isTrue,
      );
    });

    test('does not lock one second short of the timeout', () {
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded.add(const Duration(minutes: 4, seconds: 59)),
          timeout: const Duration(minutes: 5),
        ),
        isFalse,
      );
    });

    test('locks exactly at the timeout — the boundary is inclusive', () {
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded.add(const Duration(minutes: 5)),
          timeout: const Duration(minutes: 5),
        ),
        isTrue,
      );
    });

    test('locks past the timeout', () {
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded.add(const Duration(minutes: 5, seconds: 1)),
          timeout: const Duration(minutes: 5),
        ),
        isTrue,
      );
    });

    test('fails closed when the wall clock ran backwards', () {
      // Winding the device's date back is the obvious way to defeat a
      // timeout, so a negative delta locks rather than waiting it out.
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded.subtract(const Duration(hours: 1)),
          timeout: const Duration(minutes: 5),
        ),
        isTrue,
      );
    });

    test('a monotonic reading defeats a clock rewound to the same instant', () {
      // Wall clock says no time passed; the Stopwatch says ten minutes did.
      // The Stopwatch wins, so resetting the date buys nothing.
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded,
          timeout: const Duration(minutes: 5),
          monotonicElapsed: const Duration(minutes: 10),
        ),
        isTrue,
      );
    });

    test('the larger of the two readings wins', () {
      // Wall clock ahead of the Stopwatch — e.g. the device slept — still locks.
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded.add(const Duration(minutes: 30)),
          timeout: const Duration(minutes: 5),
          monotonicElapsed: const Duration(seconds: 1),
        ),
        isTrue,
      );
    });

    test('falls back to the wall clock when no monotonic reading is given', () {
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded.add(const Duration(minutes: 6)),
          timeout: const Duration(minutes: 5),
          monotonicElapsed: null,
        ),
        isTrue,
      );
    });

    test('never outranks a rewound clock', () {
      // "Never" is a deliberate user choice and is not overridden by the
      // fail-closed rule; a cold start still locks.
      expect(
        shouldLock(
          backgroundedAt: _backgrounded,
          now: _backgrounded.subtract(const Duration(days: 1)),
          timeout: null,
        ),
        isFalse,
      );
    });

    test('a DST transition expressed in UTC gives the true elapsed time', () {
      // 2026-11-01 01:30 America/New_York happens twice; in UTC it is
      // unambiguous. Backgrounding just before the repeat and resuming just
      // after is 10 real minutes, not a negative hour — which is why the
      // policy insists on UTC inputs.
      final beforeFallBack = DateTime.utc(2026, 11, 1, 5, 55); // 01:55 EDT
      final afterFallBack = DateTime.utc(2026, 11, 1, 6, 5); // 01:05 EST
      expect(
        shouldLock(
          backgroundedAt: beforeFallBack,
          now: afterFallBack,
          timeout: const Duration(minutes: 5),
        ),
        isTrue,
      );
      expect(
        shouldLock(
          backgroundedAt: beforeFallBack,
          now: afterFallBack,
          timeout: const Duration(minutes: 30),
        ),
        isFalse,
      );
    });
  });
}
