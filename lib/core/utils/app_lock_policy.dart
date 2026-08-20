import 'dart:math' as math;

/// Decides whether the app lock should re-engage after time spent in the
/// background.
///
/// Deliberately free of Flutter imports and of any notion of "now" it did not
/// receive: every input arrives as an argument, so the whole policy — including
/// the clock-tampering rules below — is unit-testable with fixed dates.
///
/// The stored setting is a plain `int` rather than a nullable one because
/// `SharedPreferences.getInt(key) ?? default` already spends the null, so a
/// second nullable layer would only add a case to forget. Two values are
/// sentinels; everything else is a count of minutes.

/// Lock the moment the app leaves the foreground.
const int autoLockImmediately = 0;

/// Never lock on a timer. The app still locks on a cold start.
const int autoLockNever = -1;

/// The minute setting as a [Duration], or null when the user chose "never".
///
/// Null means never rather than zero: zero is a real, distinct setting that
/// means "immediately", and conflating the two would turn the most permissive
/// option into the strictest one.
Duration? autoLockTimeout(int minutes) {
  if (minutes == autoLockNever) return null;
  if (minutes <= autoLockImmediately) return Duration.zero;
  return Duration(minutes: minutes);
}

/// Whether the lock should engage on resume.
///
/// [backgroundedAt] and [now] must both be UTC. Passing local time makes a DST
/// transition shift the delta by an hour in whichever direction hurts.
///
/// [monotonicElapsed] comes from a [Stopwatch] started when the app was
/// backgrounded. A `Stopwatch` measures elapsed time independently of the wall
/// clock, so it cannot be rewound by changing the device's date — which is
/// exactly the move that would otherwise buy an attacker unlimited background
/// time. When both readings are available the larger wins.
bool shouldLock({
  required DateTime? backgroundedAt,
  required DateTime now,
  required Duration? timeout,
  Duration? monotonicElapsed,
}) {
  // Nothing was ever backgrounded, so there is no elapsed time to judge.
  if (backgroundedAt == null) return false;

  // "Never" wins over every other consideration, including a rewound clock.
  // A user who picked it has said they do not want a timer; honouring that is
  // not a security hole, because the app still locks on a cold start.
  if (timeout == null) return false;

  // Answered before any arithmetic so the "immediately" edge is immune to
  // every clock question below — no subtraction, nothing to tamper with.
  if (timeout == Duration.zero) return true;

  final wallElapsed = now.difference(backgroundedAt);

  // Fail closed on a backwards clock. Moving the device's date back is the
  // obvious way to defeat a timeout, and the honest cases — an NTP correction,
  // a DST fix applied to a mis-set clock — cost the user exactly one extra
  // unlock. That trade is worth taking in a finance app.
  if (wallElapsed.isNegative) return true;

  final elapsed = monotonicElapsed == null
      ? wallElapsed
      : Duration(
          microseconds: math.max(
            wallElapsed.inMicroseconds,
            monotonicElapsed.inMicroseconds,
          ),
        );

  // Inclusive: at exactly the timeout the time is up. A five-minute setting
  // that still let you back in at 5:00.000 would be a five-minute-and-a-bit
  // setting.
  return elapsed >= timeout;
}
