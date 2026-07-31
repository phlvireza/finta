import '../../models/transaction_model.dart';

/// A merchant whose spending pattern looks like a subscription: repeated
/// charges roughly the same amount, roughly once a month.
class SubscriptionCandidate {
  final String merchant;
  final String categoryId;
  final String accountId;
  final double amount;
  final DateTime lastDate;
  final DateTime predictedNextDate;
  final int occurrenceCount;

  SubscriptionCandidate({
    required this.merchant,
    required this.categoryId,
    required this.accountId,
    required this.amount,
    required this.lastDate,
    required this.predictedNextDate,
    required this.occurrenceCount,
  });
}

/// Flags merchants that look like a recurring subscription (~monthly
/// spacing, near-identical amount, 3+ occurrences) among ordinary
/// transactions — i.e. ones the user never set up as a recurring template.
/// Pure and DB-free so the pattern-matching itself is unit-testable.
///
/// Only the most recent [lookbackOccurrences] charges per merchant are
/// considered, so a merchant used consistently for years but that changed
/// its billing cycle recently is judged on its current behavior, not its
/// whole history.
List<SubscriptionCandidate> detectSubscriptionCandidates(
  List<TransactionModel> transactions, {
  Set<String> excludeMerchants = const {},
  int minOccurrences = 3,
  int lookbackOccurrences = 6,
  double amountTolerance = 0.05,
  int minSpacingDays = 25,
  int maxSpacingDays = 35,
}) {
  final excludeLower = excludeMerchants.map((m) => m.toLowerCase()).toSet();
  final byMerchant = <String, List<TransactionModel>>{};

  for (final t in transactions) {
    if (t.isTransfer || !t.isExpense) continue;
    final merchant = t.merchant?.trim();
    if (merchant == null || merchant.isEmpty) continue;
    if (excludeLower.contains(merchant.toLowerCase())) continue;
    byMerchant.putIfAbsent(merchant, () => []).add(t);
  }

  final candidates = <SubscriptionCandidate>[];
  for (final entry in byMerchant.entries) {
    final sorted = entry.value.toList()..sort((a, b) => a.date.compareTo(b.date));
    final recent = sorted.length > lookbackOccurrences
        ? sorted.sublist(sorted.length - lookbackOccurrences)
        : sorted;
    if (recent.length < minOccurrences) continue;

    final gaps = <int>[];
    for (var i = 1; i < recent.length; i++) {
      gaps.add(recent[i].date.difference(recent[i - 1].date).inDays);
    }
    final regularSpacing = gaps.every((g) => g >= minSpacingDays && g <= maxSpacingDays);
    if (!regularSpacing) continue;

    final amounts = recent.map((t) => t.amount).toList();
    final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;
    if (avgAmount <= 0) continue;
    final consistentAmount =
        amounts.every((a) => (a - avgAmount).abs() <= avgAmount * amountTolerance);
    if (!consistentAmount) continue;

    final last = recent.last;
    final avgGap = gaps.reduce((a, b) => a + b) / gaps.length;
    candidates.add(SubscriptionCandidate(
      merchant: entry.key,
      categoryId: last.categoryId,
      accountId: last.accountId,
      amount: last.amount,
      lastDate: last.date,
      predictedNextDate: last.date.add(Duration(days: avgGap.round())),
      occurrenceCount: recent.length,
    ));
  }

  candidates.sort((a, b) => a.predictedNextDate.compareTo(b.predictedNextDate));
  return candidates;
}
