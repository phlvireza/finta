/// Escalating cooldown applied after repeated wrong PIN entries.
///
/// This — not the key-derivation cost in `pin_hasher.dart` — is what actually
/// makes guessing a six-digit PIN through the UI impractical. A million
/// candidates fall in a weekend at one guess per second; behind this schedule
/// the same search takes centuries.
///
/// The counter is persisted alongside the credential in the platform keystore
/// rather than in `SharedPreferences`, because resetting the counter is
/// precisely the attack this defends against.
///
/// Pure and clock-injected so the escalation can be asserted with fixed dates.

/// Wrong entries allowed before any cooldown starts.
///
/// Non-zero on purpose: mistyping a PIN is ordinary, and locking someone out
/// of their own ledger on the first slip would push them to turn the feature
/// off — which costs more security than the five attempts buy an attacker.
const int freeAttempts = 5;

/// Cooldown owed after [failedAttempts] consecutive wrong entries.
///
/// Returns [Duration.zero] while the user is still inside [freeAttempts].
/// The schedule escalates and then flattens: an hour is already long enough
/// that guessing is hopeless, and growing it further only punishes the
/// legitimate user who has genuinely forgotten their PIN and is about to reach
/// for the recovery path anyway.
Duration lockoutFor(int failedAttempts) {
  final over = failedAttempts - freeAttempts;
  if (over <= 0) return Duration.zero;
  switch (over) {
    case 1:
      return const Duration(seconds: 30);
    case 2:
      return const Duration(minutes: 1);
    case 3:
      return const Duration(minutes: 5);
    case 4:
      return const Duration(minutes: 15);
    default:
      return const Duration(hours: 1);
  }
}

/// The instant at which entry becomes possible again, or null when the user is
/// not currently serving a cooldown.
DateTime? lockedOutUntil({
  required int failedAttempts,
  required DateTime? lastFailedAt,
}) {
  if (lastFailedAt == null) return null;
  final cooldown = lockoutFor(failedAttempts);
  if (cooldown == Duration.zero) return null;
  return lastFailedAt.add(cooldown);
}

/// How much of the cooldown is left at [now], or [Duration.zero] when entry is
/// allowed. This is what the lock screen counts down.
///
/// [lastFailedAt] and [now] must both be UTC, for the same DST reason as
/// `app_lock_policy.dart`.
///
/// Known limit: moving the device clock *forward* skips a cooldown, and no
/// wall-clock scheme can prevent that — a [Stopwatch] would not survive the
/// force-quit an attacker would use anyway. The damage is bounded because the
/// attempt counter itself is only ever reset by a correct PIN, so each skipped
/// cooldown still escalates the next one to the one-hour cap.
Duration remainingLockout({
  required int failedAttempts,
  required DateTime? lastFailedAt,
  required DateTime now,
}) {
  final until = lockedOutUntil(
    failedAttempts: failedAttempts,
    lastFailedAt: lastFailedAt,
  );
  if (until == null) return Duration.zero;
  final remaining = until.difference(now);
  return remaining.isNegative ? Duration.zero : remaining;
}
