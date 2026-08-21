/// Rules for the unspent money left behind when a one-off budget ends.
///
/// A one-off budget covers exactly the period containing its creation date
/// (see `budget_expiry.dart`), after which `BudgetExpiryService` retires it.
/// Until now that was the end of the story: whatever the user had set aside
/// and not spent simply stopped being tracked. These functions decide when
/// that leftover is worth surfacing, and how much of it there is.
///
/// Nothing here is persisted. The leftover is recomputed from transactions
/// every load, exactly like `BudgetStatus.spent` and the rollover carry —
/// a stored copy would go stale the moment a past transaction was edited.
library;

/// The unspent portion of [amount] once [spent] is accounted for.
///
/// Clamped at zero to match `BudgetStatus.remaining`: an overspent budget
/// has no leftover to offer, and a negative "leftover" would roll forward
/// as a penalty the user never agreed to. Overspend is the rollover
/// system's business (`rolloverMode: 'full'`), not this one's.
double computeBudgetLeftover({required double amount, required double spent}) {
  final leftover = amount - spent;
  return leftover < 0 ? 0 : leftover;
}

/// Whether a budget should prompt the user to decide what happens to its
/// unspent money.
///
/// All four conditions matter:
/// - **Ended** — a live budget's "leftover" is just money it hasn't spent
///   yet, and asking about it mid-period would be nonsense.
/// - **One-off** — a recurring budget already has an answer to this
///   question in `rolloverMode`, applied every period by
///   `BudgetRolloverService`. Asking again would offer to do by hand what
///   the budget is already doing automatically.
/// - **Unanswered** — [leftoverResolvedAt] is stamped once the user picks
///   an option or dismisses, and the prompt never returns for that budget.
/// - **Something left** — a budget spent to the last cent, or overspent,
///   has nothing to decide about.
bool needsLeftoverPrompt({
  required bool isActive,
  required bool isRecurring,
  required DateTime? leftoverResolvedAt,
  required double leftover,
}) {
  if (isActive || isRecurring) return false;
  if (leftoverResolvedAt != null) return false;
  return leftover > 0;
}

/// What a budget rolled into the current period should be worth.
///
/// The leftover is added on top of the original limit rather than replacing
/// it: the user set [budgetAmount] as what this category needs in a normal
/// period, and the [leftover] is money they freed up on top of that. A
/// budget of 500 that spent 300 rolls forward as 700, not 200 — dropping to
/// 200 would quietly halve the allowance for a period they never asked to
/// economise in.
double rollForwardAmount({
  required double budgetAmount,
  required double leftover,
}) {
  return budgetAmount + leftover;
}
