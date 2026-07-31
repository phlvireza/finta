import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';

/// Free-text merchant/payee field with an autocomplete dropdown built from
/// transaction history, ranked by frequency. Picking a suggestion fires
/// [onMerchantDefaults] with that merchant's most common category/account
/// pairing, so the caller can pre-fill the rest of the form.
class MerchantField extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final void Function(String categoryId, String accountId)? onMerchantDefaults;

  const MerchantField({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.onMerchantDefaults,
  });

  @override
  State<MerchantField> createState() => _MerchantFieldState();
}

class _MerchantFieldState extends State<MerchantField> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final txProvider = context.read<TransactionProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.merchant, style: theme.textTheme.labelMedium),
          const SizedBox(height: AppConstants.spacingSm),
          RawAutocomplete<String>(
            initialValue: TextEditingValue(text: widget.initialValue ?? ''),
            optionsBuilder: (value) async {
              if (value.text.trim().isEmpty) return const Iterable<String>.empty();
              return txProvider.suggestMerchants(value.text.trim());
            },
            onSelected: (selection) async {
              widget.onChanged(selection);
              final defaults = await txProvider.getMerchantDefaults(selection);
              if (defaults != null) {
                widget.onMerchantDefaults?.call(defaults.categoryId, defaults.accountId);
              }
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: loc.merchantHint,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: widget.onChanged,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.store_outlined, size: 20),
                          title: Text(option),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
