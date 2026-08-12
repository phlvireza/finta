// Composes the two text lines a transaction row shows.
//
// Pure string assembly, kept out of the widget so the dashboard's dense
// tile and the history tile can't drift apart, and so the fallback ladder
// (which of note/merchant/category wins the title when some are missing)
// is testable without a widget tree.

/// Separator between parts of a line — the same middle dot the rest of the
/// app uses for stacked metadata.
const String transactionPartSeparator = ' · ';

/// The bold first line: what was bought, then who it was bought from.
///
/// The note leads because it is the part that says *what* the transaction
/// actually was ("2 coffees"); the merchant is context. When there's no
/// note the merchant takes the line on its own, and with neither the
/// category name is the only thing left to identify the row by.
String transactionTitle({
  required String? note,
  required String? merchant,
  required String categoryName,
  bool isTransfer = false,
  String transferLabel = 'Transfer',
}) {
  if (isTransfer) return transferLabel;

  final parts = [
    if (_isNotBlank(note)) note!.trim(),
    if (_isNotBlank(merchant)) merchant!.trim(),
  ];
  if (parts.isEmpty) return categoryName;
  return parts.join(transactionPartSeparator);
}

/// The muted second line: the classification behind the title. The note is
/// deliberately absent — [transactionTitle] already shows it, and
/// repeating it would push the account name off the end of the line.
///
/// [goalOrDebtName] is the goal or debt this transaction was logged against,
/// when it was one. It goes last because it is the rarest part, and it is
/// here at all because a contribution used to be indistinguishable from any
/// other "Savings & Goals" expense — which made an archived goal's history
/// impossible to find, and the category now being user-selectable would have
/// removed the last hint that a transaction was a contribution.
///
/// Resolved by the caller rather than looked up here: this file is pure
/// string assembly and reaching for a provider would make it untestable
/// without a widget tree.
String transactionSubtitle({
  required String categoryName,
  required String? accountName,
  String? goalOrDebtName,
  bool isTransfer = false,
}) {
  final parts = [
    if (!isTransfer) categoryName,
    if (_isNotBlank(accountName)) accountName!.trim(),
    if (_isNotBlank(goalOrDebtName)) goalOrDebtName!.trim(),
  ];
  return parts.join(transactionPartSeparator);
}

bool _isNotBlank(String? value) => value != null && value.trim().isNotEmpty;
