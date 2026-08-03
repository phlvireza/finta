import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/expression_evaluator.dart';
import '../../../l10n/app_localizations.dart';

/// A small calculator bottom sheet for the amount field — type an
/// expression like `12000+3500`, hit `=`, and the result is popped back to
/// the caller. Kept separate from [AmountInputField]'s own text field
/// (rather than letting operators through its comma-formatting
/// [CurrencyInputFormatter]) since that formatter's job is strict numeric
/// masking and teaching it arithmetic would risk breaking plain typing.
class CalculatorSheet extends StatefulWidget {
  final String? initialValue;

  const CalculatorSheet({super.key, this.initialValue});

  static Future<double?> show(BuildContext context, {String? initialValue}) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CalculatorSheet(initialValue: initialValue),
    );
  }

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String _expression = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue?.replaceAll(',', '');
    if (initial != null && initial.isNotEmpty && initial != '0') {
      _expression = initial;
    }
  }

  void _append(String token) {
    setState(() {
      _expression += token;
      _error = null;
    });
  }

  void _backspace() {
    if (_expression.isEmpty) return;
    setState(() {
      _expression = _expression.substring(0, _expression.length - 1);
      _error = null;
    });
  }

  void _clear() {
    setState(() {
      _expression = '';
      _error = null;
    });
  }

  void _equals() {
    final loc = AppLocalizations.of(context)!;
    final result = evaluateExpression(_expression);
    if (result == null) {
      setState(() => _error = loc.invalidExpression);
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(loc.calculator, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppConstants.spacingMd),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.spacingLg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                // Grouped for reading only — `_expression` itself stays raw
                // so [evaluateExpression] never sees a comma.
                child: Text(
                  _expression.isEmpty
                      ? '0'
                      : formatExpressionWithSeparators(_expression),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppConstants.spacingXs),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: AppConstants.spacingLg),
              _row(['7', '8', '9', '÷']),
              _row(['4', '5', '6', '×']),
              _row(['1', '2', '3', '−']),
              _row(['C', '0', '.', '+']),
              const SizedBox(height: AppConstants.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _backspace,
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Icon(Icons.backspace_outlined),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _equals,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('=', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Row(
        children: [
          for (final key in keys) ...[
            Expanded(child: _key(key)),
            if (key != keys.last) const SizedBox(width: AppConstants.spacingSm),
          ],
        ],
      ),
    );
  }

  Widget _key(String label) {
    final isOperator = ['÷', '×', '−', '+'].contains(label);
    final isClear = label == 'C';
    return OutlinedButton(
      onPressed: () {
        if (isClear) {
          _clear();
        } else if (label == '÷') {
          _append('/');
        } else if (label == '×') {
          _append('*');
        } else if (label == '−') {
          _append('-');
        } else {
          _append(label);
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        foregroundColor: isOperator ? Theme.of(context).colorScheme.primary : null,
      ),
      child: Text(label, style: const TextStyle(fontSize: 18)),
    );
  }
}
