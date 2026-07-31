/// Months needed to clear [outstanding] at a fixed [monthlyPayment],
/// applying [monthlyInterestRate] (as a fraction, e.g. 0.01 for 1%/month)
/// to the remaining balance before each payment. A flat month-by-month
/// simulation rather than a closed-form amortization formula, since it
/// has to handle the zero-interest case identically without branching.
///
/// Returns null if the debt can never be paid off (payment too small to
/// outpace interest, capped at 100 years of simulation) or if
/// [monthlyPayment] isn't positive. Returns 0 if already paid off.
int? monthsToPayOff({
  required double outstanding,
  required double monthlyPayment,
  double monthlyInterestRate = 0,
}) {
  if (outstanding <= 0) return 0;
  if (monthlyPayment <= 0) return null;

  const maxMonths = 1200;
  var balance = outstanding;
  var months = 0;
  while (balance > 0 && months < maxMonths) {
    balance += balance * monthlyInterestRate;
    balance -= monthlyPayment;
    months++;
  }
  return balance > 0 ? null : months;
}
