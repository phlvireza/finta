/// Expiry rule for non-recurring ("one-off") budgets.
///
/// Budgets carry no period anchor of their own — the range that applies is
/// derived at read time. A one-off budget therefore takes the period that
/// *contains its creation date* as the one and only period it covers;
/// `BudgetExpiryService` walks active budgets at startup and deactivates
/// the ones this function reports as done.
library;

/// Whether a budget created in [originPeriod] has outlived its purpose as
/// of [today].
///
/// A recurring budget never expires — it is meant to re-apply forever, so
/// the answer is always false regardless of [originPeriod].
///
/// The comparison is date-only on both sides: [originPeriod] ends are
/// midnight-stamped days, and a `DateTime.now()` passed straight in would
/// otherwise read as "after" the final day from 00:00:01 onward, ending a
/// budget a full period early.
bool isBudgetExpired({
  required bool isRecurring,
  required ({DateTime start, DateTime end}) originPeriod,
  required DateTime today,
}) {
  if (isRecurring) return false;

  final todayDate = DateTime(today.year, today.month, today.day);
  final endDate = DateTime(
    originPeriod.end.year,
    originPeriod.end.month,
    originPeriod.end.day,
  );

  // Inclusive: the budget is still live *on* its final day.
  return todayDate.isAfter(endDate);
}
