// Merchant name handling.
//
// Merchant is free text typed by the user, so the same shop arrives spelled
// a dozen ways — "Netflix", "netflix", "Netflix " and "Net  flix" are one
// merchant to a human and four to a `GROUP BY`. Every feature that counts
// per-merchant (top spend, subscription detection) has to agree on how names
// fold together, which is why the rule lives here rather than being inlined
// at each call site.

/// Grouping key for a merchant name: trimmed, internal whitespace collapsed
/// to single spaces, lowercased.
///
/// Deliberately kept in Dart rather than pushed into SQL as
/// `LOWER(TRIM(merchant))`: SQLite's `LOWER` is ASCII-only and cannot collapse
/// internal whitespace, so a SQL-side fold and a Dart-side fold would disagree
/// on exactly the names users are most likely to mistype. One implementation,
/// used by both the aggregation and the drill-down that has to match it.
String normalizeMerchant(String raw) => displayMerchant(raw).toLowerCase();

/// The same tidy-up as [normalizeMerchant] but with the user's capitalisation
/// left alone — what a merchant should actually be shown as.
///
/// Collapsing whitespace here too means every spelling of one merchant reduces
/// to the same length, so choosing between them is purely a question of case
/// rather than of who typed a stray double space.
String displayMerchant(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Whether [raw] holds anything worth grouping on. Blank and whitespace-only
/// merchants are not a merchant named "" — they're an absent merchant, and
/// lumping them into one bucket would invent a top spender.
bool hasMerchant(String? raw) => raw != null && raw.trim().isNotEmpty;

/// One merchant's spend over a period, after variants have been folded.
class MerchantAnalytics {
  /// The spelling to show, chosen by [foldMerchantTotals] from the variants
  /// that were folded together.
  final String merchant;

  /// [normalizeMerchant] of [merchant]. Carried so a drill-down can match the
  /// same rows this total was folded from without re-deriving the rule.
  final String key;

  final double total;
  final int count;

  const MerchantAnalytics({
    required this.merchant,
    required this.key,
    required this.total,
    required this.count,
  });
}

/// Add per-spelling merchant totals together and rank them, keeping the top
/// [limit].
///
/// The fold has to happen before the cut, not after: a merchant can be the
/// largest spend of a period and still miss a top-N taken over raw spellings,
/// because each variant carries only part of the total. That is also why the
/// database query this consumes is deliberately unranked and unlimited.
List<MerchantAnalytics> foldMerchantTotals(
  Iterable<({String merchant, double total, int count})> rows, {
  int limit = 10,
}) {
  final folded = <String, _FoldedMerchant>{};

  for (final row in rows) {
    if (!hasMerchant(row.merchant)) continue;
    final name = displayMerchant(row.merchant);
    final key = normalizeMerchant(name);
    (folded[key] ??= _FoldedMerchant(key)).add(name, row.total, row.count);
  }

  final ranked = folded.values.map((m) => m.result).toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return limit >= ranked.length ? ranked : ranked.sublist(0, limit);
}

/// Accumulator for one merchant while its spellings are being merged.
class _FoldedMerchant {
  final String key;
  double total = 0;
  int count = 0;

  String? _name;
  int _nameCount = 0;

  _FoldedMerchant(this.key);

  void add(String name, double rowTotal, int rowCount) {
    total += rowTotal;
    count += rowCount;
    if (_name == null || _beats(name, rowCount, _name!, _nameCount)) {
      _name = name;
      _nameCount = rowCount;
    }
  }

  MerchantAnalytics get result => MerchantAnalytics(
        merchant: _name ?? key,
        key: key,
        total: total,
        count: count,
      );

  /// Whether spelling [a] should be shown instead of [b].
  ///
  /// The spelling used most often wins — it's the one the user actually
  /// types. Ties go to mixed case, because a tie means the variants differ
  /// only in capitalisation and "Netflix" is what someone wrote while
  /// "NETFLIX" and "netflix" are a stuck shift key and a hurried entry. Left
  /// to source order this was decided by however the database happened to
  /// return the rows, which is not stable and skewed towards shouting.
  static bool _beats(String a, int aCount, String b, int bCount) {
    if (aCount != bCount) return aCount > bCount;
    return _isMixedCase(a) && !_isMixedCase(b);
  }

  static bool _isMixedCase(String value) =>
      value != value.toUpperCase() && value != value.toLowerCase();
}
