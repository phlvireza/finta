import '../../models/transaction_model.dart';

/// Expense total per calendar day, keyed by a date-only [DateTime].
///
/// Transfers are movements between the user's own accounts and were never
/// spending, so they are excluded — the same rule
/// `TransactionRepository.getByTypeAndDateRange` applies. Income is excluded
/// too: this feeds the spending heatmap, where a salary landing would
/// otherwise read as the heaviest "spending" day of the period.
///
/// Days with no expenses are simply absent from the map rather than present
/// with a zero, so callers can distinguish "nothing happened" without
/// materialising every day in the range.
Map<DateTime, double> dailyExpenseTotals(List<TransactionModel> transactions) {
  final totals = <DateTime, double>{};

  for (final transaction in transactions) {
    if (!transaction.isExpense || transaction.isTransfer) continue;
    final day = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    totals[day] = (totals[day] ?? 0) + transaction.amount;
  }

  return totals;
}

/// The largest single-day total in [totals], or 0 when there is nothing to
/// compare against. Callers scale cell intensity against this, so it is the
/// one place the "empty period" divide-by-zero is handled.
double maxDailyTotal(Map<DateTime, double> totals) {
  if (totals.isEmpty) return 0;
  return totals.values.reduce((a, b) => a > b ? a : b);
}
