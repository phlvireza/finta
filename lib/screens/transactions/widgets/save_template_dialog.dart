import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/template_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Saves the current form values as a one-tap quick-add template, after
/// asking for a name (pre-filled with the merchant, or the category when
/// there is none).
///
/// Shared by the quick-add sheet and the full add screen: both offer the
/// same bookmark action, and duplicating the dialog in each one is how the
/// two would drift.
///
/// Shows its own feedback snackbar and returns the saved name, or null if
/// the form isn't complete enough to template or the dialog was dismissed.
///
/// When [onFeedback] is provided, uses it to present validation/success
/// messages instead of a SnackBar (useful when called from a modal that
/// would hide the SnackBar behind itself).
Future<String?> saveAsTemplate(
  BuildContext context, {
  required bool isIncome,
  required double amount,
  required String? categoryId,
  required String? accountId,
  required String? merchant,
  required String? note,
  void Function(String message, {required bool isError})? onFeedback,
}) async {
  final loc = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  void showFeedback(String message, {required bool isError}) {
    if (onFeedback != null) {
      onFeedback(message, isError: isError);
    } else {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  if (categoryId == null || accountId == null || amount <= 0) {
    showFeedback(loc.fillOutFormFirst, isError: true);
    return null;
  }

  final trimmedMerchant = merchant?.trim();
  final trimmedNote = note?.trim();
  final category = context.read<CategoryProvider>().getCategoryById(categoryId);
  final nameController = TextEditingController(
    text: (trimmedMerchant?.isNotEmpty ?? false) ? trimmedMerchant! : (category?.name ?? ''),
  );
  final templates = context.read<TemplateProvider>();

  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(loc.saveAsTemplate),
      content: TextField(
        controller: nameController,
        autofocus: true,
        decoration: InputDecoration(labelText: loc.templateName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(nameController.text.trim()),
          child: Text(loc.save),
        ),
      ],
    ),
  );
  nameController.dispose();
  if (name == null || name.isEmpty) return null;

  await templates.addTemplate(
    name: name,
    type: isIncome ? 'income' : 'expense',
    amount: amount,
    categoryId: categoryId,
    accountId: accountId,
    merchant: (trimmedMerchant == null || trimmedMerchant.isEmpty) ? null : trimmedMerchant,
    note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
  );

  showFeedback(loc.templateSaved(name), isError: false);
  return name;
}

/// Explains what a template is, from the (i) beside the bookmark action.
///
/// Lived as a byte-identical private `_showTemplateInfo` in both the
/// quick-add sheet and the full add screen; it sits beside [saveAsTemplate]
/// for the same reason that function does.
void showTemplateInfo(BuildContext context, AppLocalizations loc) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(loc.saveAsTemplate),
      content: Text(loc.saveAsTemplateHelp),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(loc.gotIt),
        ),
      ],
    ),
  );
}
