/// Which fields on the Add Transaction form are still missing before its
/// current values can be saved as a one-tap quick-add template.
enum MissingTemplateField { amount, category, account }

/// Returns the empty set when the form has enough filled in to save as a
/// template (a valid amount, a category, and an account).
Set<MissingTemplateField> missingTemplateFields({
  required double amount,
  required String? categoryId,
  required String? accountId,
}) {
  final missing = <MissingTemplateField>{};
  if (amount <= 0) missing.add(MissingTemplateField.amount);
  if (categoryId == null) missing.add(MissingTemplateField.category);
  if (accountId == null) missing.add(MissingTemplateField.account);
  return missing;
}
