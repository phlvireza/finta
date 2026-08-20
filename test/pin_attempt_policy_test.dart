import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/pin_attempt_policy.dart';

final _lastFailed = DateTime.utc(2026, 5, 20, 8, 0, 0);

void main() {
  group('lockoutFor', () {
    test('the first five wrong entries cost nothing', () {
      // Mistyping is ordinary; locking someone out of their own ledger on the
      // first slip would push them to turn the feature off entirely.
      for (var attempts = 0; attempts <= freeAttempts; attempts++) {
        expect(lockoutFor(attempts), Duration.zero, reason: 'attempt $attempts');
      }
    });

    test('escalates through the schedule after the free attempts', () {
      expect(lockoutFor(6), const Duration(seconds: 30));
      expect(lockoutFor(7), const Duration(minutes: 1));
      expect(lockoutFor(8), const Duration(minutes: 5));
      expect(lockoutFor(9), const Duration(minutes: 15));
    });

    test('flattens at one hour rather than growing without bound', () {
      // An hour already makes exhaustive guessing hopeless; growing further
      // only punishes a user who has genuinely forgotten and is heading for
      // the recovery path anyway.
      expect(lockoutFor(10), const Duration(hours: 1));
      expect(lockoutFor(50), const Duration(hours: 1));
      expect(lockoutFor(100000), const Duration(hours: 1));
    });

    test('a negative count is treated as no failures', () {
      expect(lockoutFor(-1), Duration.zero);
    });
  });

  group('lockedOutUntil', () {
    test('is null when nothing has failed yet', () {
      expect(lockedOutUntil(failedAttempts: 0, lastFailedAt: null), isNull);
    });

    test('is null while inside the free attempts', () {
      expect(lockedOutUntil(failedAttempts: 3, lastFailedAt: _lastFailed), isNull);
    });

    test('is null when the attempt count is past the free window but no timestamp exists', () {
      // A stored counter without a timestamp is a malformed record; refusing
      // to invent a deadline is better than locking the user out forever.
      expect(lockedOutUntil(failedAttempts: 9, lastFailedAt: null), isNull);
    });

    test('is the last failure plus the cooldown owed', () {
      expect(
        lockedOutUntil(failedAttempts: 6, lastFailedAt: _lastFailed),
        _lastFailed.add(const Duration(seconds: 30)),
      );
      expect(
        lockedOutUntil(failedAttempts: 9, lastFailedAt: _lastFailed),
        _lastFailed.add(const Duration(minutes: 15)),
      );
    });
  });

  group('remainingLockout', () {
    test('is zero while inside the free attempts', () {
      expect(
        remainingLockout(
          failedAttempts: 5,
          lastFailedAt: _lastFailed,
          now: _lastFailed,
        ),
        Duration.zero,
      );
    });

    test('counts down as time passes', () {
      expect(
        remainingLockout(
          failedAttempts: 6,
          lastFailedAt: _lastFailed,
          now: _lastFailed.add(const Duration(seconds: 10)),
        ),
        const Duration(seconds: 20),
      );
    });

    test('is zero once the cooldown has fully elapsed', () {
      expect(
        remainingLockout(
          failedAttempts: 6,
          lastFailedAt: _lastFailed,
          now: _lastFailed.add(const Duration(seconds: 30)),
        ),
        Duration.zero,
      );
    });

    test('is zero long after the cooldown, never negative', () {
      // The lock screen renders this directly, so a negative would show as a
      // nonsense countdown.
      expect(
        remainingLockout(
          failedAttempts: 9,
          lastFailedAt: _lastFailed,
          now: _lastFailed.add(const Duration(days: 1)),
        ),
        Duration.zero,
      );
    });

    test('a rewound clock lengthens the wait rather than clearing it', () {
      // Fail closed, matching app_lock_policy: winding the date back must not
      // be a way out of a cooldown.
      expect(
        remainingLockout(
          failedAttempts: 6,
          lastFailedAt: _lastFailed,
          now: _lastFailed.subtract(const Duration(minutes: 5)),
        ),
        const Duration(minutes: 5, seconds: 30),
      );
    });

    test('an old failure does not resurrect a cooldown on the next launch', () {
      // Counter still high, but the last failure was yesterday — entry is
      // allowed again immediately, and the *next* wrong entry escalates.
      expect(
        remainingLockout(
          failedAttempts: 12,
          lastFailedAt: _lastFailed,
          now: _lastFailed.add(const Duration(hours: 2)),
        ),
        Duration.zero,
      );
    });
  });
}
