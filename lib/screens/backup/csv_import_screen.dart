import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_typography.dart';
import '../../core/services/csv_import_service.dart';
import '../../core/utils/csv_import_preview.dart';
import '../../core/utils/number_utils.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/masked_amount.dart';
import '../../widgets/status_pill.dart';
import '../transactions/widgets/account_picker.dart';

/// One line in the preview list.
///
/// Flattened into a single list rather than nested per-section builders so
/// the whole preview is one lazy [ListView.builder] — a bank export can run
/// to thousands of rows, and every one of them is rendered here.
sealed class _PreviewEntry {
  const _PreviewEntry();
}

class _SectionEntry extends _PreviewEntry {
  final String title;
  const _SectionEntry(this.title);
}

class _RowEntry extends _PreviewEntry {
  final ParsedImportRow row;
  final bool createsCategory;
  const _RowEntry(this.row, {required this.createsCategory});
}

class _ErrorEntry extends _PreviewEntry {
  final CsvImportError error;
  const _ErrorEntry(this.error);
}

/// Column-mapping → preview → import flow for an arbitrary CSV (Squirio's
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

  /// Built once per preview run rather than in `build`, so scrolling a large
  /// file doesn't re-derive the whole list on every frame.
  List<_PreviewEntry> _entries = const [];
  List<String> _newCategories = const [];

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

  /// The (type, name) keys of the categories the user already has.
  ///
  /// System categories are excluded to match [_findCategory], which refuses
  /// to reuse them — counting them as existing would under-report what the
  /// import is about to create.
  Set<String> _existingCategoryKeys(List<CategoryModel> categories) => {
    for (final c in categories)
      if (!c.isSystem) categoryKey(c.type, c.name),
  };

  void _runPreview() {
    final loc = AppLocalizations.of(context)!;
    final mapping = CsvColumnMapping(
      date: _dateCol,
      amount: _amountCol,
      type: _typeCol,
      category: _categoryCol,
      note: _noteCol,
      merchant: _merchantCol,
    );
    final result = _service.mapRows(_parsed.dataRows, mapping);

    final existingKeys = _existingCategoryKeys(
      context.read<CategoryProvider>().categories,
    );
    final fallback = loc.importedCategoryName;
    final newCategories = pendingNewCategories(
      rows: result.rows,
      existingKeys: existingKeys,
      fallbackName: fallback,
    );

    final entries = <_PreviewEntry>[
      if (result.rows.isNotEmpty) ...[
        _SectionEntry(loc.csvPreviewReadySection(result.rows.length)),
        for (final row in result.rows)
          _RowEntry(
            row,
            createsCategory: isNewCategory(
              row: row,
              existingKeys: existingKeys,
              fallbackName: fallback,
            ),
          ),
      ],
      if (result.errors.isNotEmpty) ...[
        _SectionEntry(loc.csvPreviewSkippedSection(result.errors.length)),
        for (final error in result.errors) _ErrorEntry(error),
      ],
    ];

    setState(() {
      _rows = result.rows;
      _errors = result.errors;
      _entries = entries;
      _newCategories = newCategories;
      _previewing = true;
    });
  }

  CategoryModel? _findCategory(
    List<CategoryModel> categories,
    String name,
    String type,
  ) {
    final lower = name.toLowerCase();
    for (final c in categories) {
      if (c.type == type && !c.isSystem && c.name.toLowerCase() == lower) {
        return c;
      }
    }
    return null;
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

      // Resolve each distinct (type, name) once up front. Doing it inside the
      // row loop meant a linear scan of every category per row, so a 500-row
      // file over five categories did 500 scans and re-checked the same
      // just-created category 100 times.
      final categoryIds = <String, String>{};
      for (final row in _rows) {
        final name = row.categoryName ?? loc.importedCategoryName;
        final key = categoryKey(row.type, name);
        if (categoryIds.containsKey(key)) continue;

        var category = _findCategory(
          categoryProvider.categories,
          name,
          row.type,
        );
        if (category == null) {
          await categoryProvider.addCategory(
            name: name,
            type: row.type,
            icon: 'category',
            color: '#8A7E74',
          );
          category = _findCategory(categoryProvider.categories, name, row.type);
        }
        categoryIds[key] = category!.id;
      }

      for (final row in _rows) {
        final name = row.categoryName ?? loc.importedCategoryName;
        toInsert.add(
          TransactionModel(
            id: _uuid.v4(),
            type: row.type,
            amount: row.amount,
            categoryId: categoryIds[categoryKey(row.type, name)]!,
            accountId: _accountId!,
            merchant: row.merchant,
            date: row.date,
            note: row.note,
            createdAt: now,
            updatedAt: now,
          ),
        );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.importFailed)));
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
              _columnDropdown(
                loc.csvColumnDate,
                _dateCol,
                required: true,
                onChanged: (v) => setState(() => _dateCol = v),
              ),
              _columnDropdown(
                loc.csvColumnAmount,
                _amountCol,
                required: true,
                onChanged: (v) => setState(() => _amountCol = v),
              ),
              _columnDropdown(
                loc.csvColumnType,
                _typeCol,
                required: false,
                onChanged: (v) => setState(() => _typeCol = v),
              ),
              _columnDropdown(
                loc.csvColumnCategory,
                _categoryCol,
                required: false,
                onChanged: (v) => setState(() => _categoryCol = v),
              ),
              _columnDropdown(
                loc.csvColumnMerchant,
                _merchantCol,
                required: false,
                onChanged: (v) => setState(() => _merchantCol = v),
              ),
              _columnDropdown(
                loc.csvColumnNote,
                _noteCol,
                required: false,
                onChanged: (v) => setState(() => _noteCol = v),
              ),
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
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingLg,
            AppConstants.spacingLg,
            AppConstants.spacingLg,
            AppConstants.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.csvImportSummary(_rows.length, _errors.length),
                style: theme.textTheme.titleMedium,
              ),
              // Confirming the import creates these silently, so say so
              // before the user commits rather than after.
              if (_newCategories.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  loc.csvNewCategoriesNote(_newCategories.join(', ')),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingLg),
            itemCount: _entries.length,
            // The builder's own context, not the State's: these run during
            // layout, when the screen's element is no longer building, and
            // `watch`/`Theme.of` against a context that isn't building is
            // exactly the case provider asserts on.
            itemBuilder: (itemContext, i) => switch (_entries[i]) {
              _SectionEntry(:final title) => _sectionHeader(itemContext, title),
              _RowEntry(:final row, :final createsCategory) => _previewRow(
                itemContext,
                loc,
                row,
                createsCategory: createsCategory,
              ),
              _ErrorEntry(:final error) => _errorRow(itemContext, loc, error),
            },
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

  Widget _sectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingXs,
      ),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _previewRow(
    BuildContext context,
    AppLocalizations loc,
    ParsedImportRow row, {
    required bool createsCategory,
  }) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final isIncome = row.type == 'income';
    final amountColor = isIncome
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

    final details = [
      DateFormat.yMMMd().format(row.date),
      if (row.merchant != null) row.merchant!,
      if (row.note != null) row.note!,
    ].join(' · ');

    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 28,
        child: Text(
          '${row.rowNumber}',
          textAlign: TextAlign.end,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              row.categoryName ?? loc.importedCategoryName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (createsCategory)
            Padding(
              padding: const EdgeInsets.only(left: AppConstants.spacingSm),
              child: StatusPill(
                label: loc.csvCategoryNew,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      subtitle: Text(details, overflow: TextOverflow.ellipsis),
      trailing: MaskedAmount(
        text:
            '${isIncome ? '+' : '-'} ${NumberUtils.formatCurrency(row.amount, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals)}',
        style: AppTypography.amountStyle(color: amountColor, fontSize: 14),
      ),
    );
  }

  Widget _errorRow(
    BuildContext context,
    AppLocalizations loc,
    CsvImportError error,
  ) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
      title: Text(loc.csvRowNumber(error.rowNumber)),
      subtitle: Text(error.reason),
    );
  }
}
