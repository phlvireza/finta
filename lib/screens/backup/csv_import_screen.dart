import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/csv_import_service.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../l10n/app_localizations.dart';
import '../transactions/widgets/account_picker.dart';
import '../../core/utils/category_display.dart';

/// Column-mapping → preview → import flow for an arbitrary CSV (Finta's
/// own export, or a bank/other app's). Only the date and amount columns
/// are required; everything else degrades gracefully (missing type is
/// inferred from the amount's sign, missing category falls back to an
/// "Imported" bucket).
class CsvImportScreen extends StatefulWidget {
  final String csvContent;

  const CsvImportScreen({super.key, required this.csvContent});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  static final _service = CsvImportService();
  static const _uuid = Uuid();

  late final CsvParseResult _parsed;
  int _dateCol = -1;
  int _amountCol = -1;
  int _typeCol = -1;
  int _categoryCol = -1;
  int _noteCol = -1;
  int _merchantCol = -1;
  String? _accountId;

  bool _previewing = false;
  bool _importing = false;
  List<ParsedImportRow> _rows = const [];
  List<CsvImportError> _errors = const [];

  @override
  void initState() {
    super.initState();
    _parsed = _service.parse(widget.csvContent);
    _dateCol = _guessColumn(['date']);
    _amountCol = _guessColumn(['amount', 'value']);
    _typeCol = _guessColumn(['type']);
    _categoryCol = _guessColumn(['category']);
    _noteCol = _guessColumn(['note', 'description', 'memo']);
    _merchantCol = _guessColumn(['merchant', 'payee']);
  }

  int _guessColumn(List<String> candidates) {
    for (var i = 0; i < _parsed.headers.length; i++) {
      final h = _parsed.headers[i].toLowerCase();
      if (candidates.any(h.contains)) return i;
    }
    return -1;
  }

  void _runPreview() {
    final mapping = CsvColumnMapping(
      date: _dateCol,
      amount: _amountCol,
      type: _typeCol,
      category: _categoryCol,
      note: _noteCol,
      merchant: _merchantCol,
    );
    final result = _service.mapRows(_parsed.dataRows, mapping);
    setState(() {
      _rows = result.rows;
      _errors = result.errors;
      _previewing = true;
    });
  }

  Future<void> _confirmImport() async {
    setState(() => _importing = true);
    final loc = AppLocalizations.of(context)!;
    final categoryProvider = context.read<CategoryProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final accountProvider = context.read<AccountProvider>();
    final settings = context.read<SettingsProvider>();

    try {
      final now = DateTime.now();
      final toInsert = <TransactionModel>[];

      for (final row in _rows) {
        final targetName = row.categoryName ?? loc.importedCategoryName;
        var category = findCategoryByAnyName(
          categories: categoryProvider.categories,
          name: targetName,
          type: row.type,
          loc: loc,
        );
        if (category == null) {
          await categoryProvider.addCategory(
            name: targetName,
            type: row.type,
            icon: 'category',
            color: '#8A7E74',
          );
          category = findCategoryByAnyName(
            categories: categoryProvider.categories,
            name: targetName,
            type: row.type,
            loc: loc,
          );
        }
        toInsert.add(TransactionModel(
          id: _uuid.v4(),
          type: row.type,
          amount: row.amount,
          categoryId: category!.id,
          accountId: _accountId!,
          merchant: row.merchant,
          date: row.date,
          note: row.note,
          createdAt: now,
          updatedAt: now,
        ));
      }

      await transactionProvider.importTransactions(toInsert);
      await Future.wait([
        transactionProvider.loadAllTransactions(),
        transactionProvider.loadTransactions(payday: settings.payday),
        accountProvider.loadAccounts(),
      ]);

      if (mounted) Navigator.of(context).pop(toInsert.length);
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.importFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_previewing ? loc.reviewImport : loc.mapCsvColumns),
        leading: _previewing
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _previewing = false),
              )
            : null,
      ),
      body: _previewing ? _buildPreview(loc) : _buildMapping(loc),
    );
  }

  Widget _buildMapping(AppLocalizations loc) {
    final canPreview = _dateCol >= 0 && _amountCol >= 0 && _accountId != null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            children: [
              Text(
                loc.csvRowsFound(_parsed.dataRows.length),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppConstants.spacingLg),
              _columnDropdown(loc.csvColumnDate, _dateCol, required: true, onChanged: (v) => setState(() => _dateCol = v)),
              _columnDropdown(loc.csvColumnAmount, _amountCol, required: true, onChanged: (v) => setState(() => _amountCol = v)),
              _columnDropdown(loc.csvColumnType, _typeCol, required: false, onChanged: (v) => setState(() => _typeCol = v)),
              _columnDropdown(loc.csvColumnCategory, _categoryCol, required: false, onChanged: (v) => setState(() => _categoryCol = v)),
              _columnDropdown(loc.csvColumnMerchant, _merchantCol, required: false, onChanged: (v) => setState(() => _merchantCol = v)),
              _columnDropdown(loc.csvColumnNote, _noteCol, required: false, onChanged: (v) => setState(() => _noteCol = v)),
              const SizedBox(height: AppConstants.spacingLg),
              AccountPicker(
                label: loc.csvImportToAccount,
                selectedAccountId: _accountId,
                onAccountSelected: (id) => setState(() => _accountId = id),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canPreview ? _runPreview : null,
              child: Text(loc.previewImport),
            ),
          ),
        ),
      ],
    );
  }

  Widget _columnDropdown(
    String label,
    int value, {
    required bool required,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
        items: [
          if (!required) const DropdownMenuItem(value: -1, child: Text('—')),
          for (var i = 0; i < _parsed.headers.length; i++)
            DropdownMenuItem(value: i, child: Text(_parsed.headers[i])),
        ],
        onChanged: (v) => onChanged(v ?? -1),
      ),
    );
  }

  Widget _buildPreview(AppLocalizations loc) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loc.csvImportSummary(_rows.length, _errors.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        if (_errors.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
              itemCount: _errors.length,
              itemBuilder: (context, i) {
                final err = _errors[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                  title: Text(loc.csvRowNumber(err.rowNumber)),
                  subtitle: Text(err.reason),
                );
              },
            ),
          )
        else
          Expanded(
            child: Center(
              child: Text(loc.csvNoErrors, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_rows.isEmpty || _importing) ? null : _confirmImport,
              child: _importing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(loc.confirmImportCount(_rows.length)),
            ),
          ),
        ),
      ],
    );
  }
}
