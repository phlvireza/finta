import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_typography.dart';
import '../../core/database/seed_data.dart';
import '../../core/services/csv_import_service.dart';
import '../../core/utils/csv_import_preview.dart';
import '../../core/utils/number_utils.dart';
import '../../models/account_model.dart';
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
  int _accountCol = -1;
  int _toAccountCol = -1;
  String? _accountId;

  bool _previewing = false;
  bool _importing = false;
  List<ParsedImportRow> _rows = const [];
  List<CsvImportError> _errors = const [];

  /// Built once per preview run rather than in `build`, so scrolling a large
  /// file doesn't re-derive the whole list on every frame.
  List<_PreviewEntry> _entries = const [];
  List<String> _newCategories = const [];
  List<String> _newAccounts = const [];

  /// Every count on screen is a *row* count, so the file, the preview and the
  /// button can never disagree. These two exist only to explain the gap between
  /// the rows in the file and the entries the ledger gains: a transfer row is
  /// stored as two linked legs.
  int _entryCount = 0;
  int _transferRowCount = 0;

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
    // Destination first, and its column excluded from the source guess:
    // "To Account" contains "account", so guessing the source first would
    // claim the destination column and leave every transfer without one.
    _toAccountCol = _guessColumn(['to account', 'destination']);
    _accountCol = _guessColumn(['account', 'wallet'], skip: _toAccountCol);
  }

  int _guessColumn(List<String> candidates, {int skip = -1}) {
    for (var i = 0; i < _parsed.headers.length; i++) {
      if (i == skip) continue;
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
    final accountProvider = context.read<AccountProvider>();
    final mapping = CsvColumnMapping(
      date: _dateCol,
      amount: _amountCol,
      type: _typeCol,
      category: _categoryCol,
      note: _noteCol,
      merchant: _merchantCol,
      account: _accountCol,
      toAccount: _toAccountCol,
    );
    final result = _service.mapRows(_parsed.dataRows, mapping);

    final existingKeys = _existingCategoryKeys(
      context.read<CategoryProvider>().categories,
    );
    final fallbackCategory = loc.importedCategoryName;
    final fallbackAccount =
        accountProvider.getAccountById(_accountId!)?.name ?? '';

    final newCategories = pendingNewCategories(
      rows: result.rows,
      existingKeys: existingKeys,
      fallbackName: fallbackCategory,
    );
    final newAccounts = pendingNewAccounts(
      rows: result.rows,
      existingKeys: {
        for (final a in accountProvider.accounts) accountKey(a.name),
      },
      fallbackName: fallbackAccount,
    );

    // Two error sources: the parser's, and the ones only answerable once the
    // fallback account is known. Rows failing the latter drop out of the ready
    // list, and both are shown in one list ordered by position in the file.
    final transferErrors = transferRowErrors(
      rows: result.rows,
      fallbackName: fallbackAccount,
    );
    final rejected = {for (final e in transferErrors) e.rowNumber};
    final rows = result.rows.where((r) => !rejected.contains(r.rowNumber));
    final errors = [...result.errors, ...transferErrors]
      ..sort((a, b) => a.rowNumber.compareTo(b.rowNumber));

    final ready = rows.toList();

    final entries = <_PreviewEntry>[
      if (ready.isNotEmpty) ...[
        _SectionEntry(loc.csvPreviewReadySection(ready.length)),
        for (final row in ready)
          _RowEntry(
            row,
            createsCategory: isNewCategory(
              row: row,
              existingKeys: existingKeys,
              fallbackName: fallbackCategory,
            ),
          ),
      ],
      if (errors.isNotEmpty) ...[
        _SectionEntry(loc.csvPreviewSkippedSection(errors.length)),
        for (final error in errors) _ErrorEntry(error),
      ],
    ];

    setState(() {
      _rows = ready;
      _errors = errors;
      _entries = entries;
      _newCategories = newCategories;
      _newAccounts = newAccounts;
      _entryCount = ledgerEntryCount(ready);
      _transferRowCount = transferRowCount(ready);
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
        // Transfers are pinned to the system Transfer category, which
        // _findCategory deliberately refuses to match — resolving them here
        // would create a duplicate user category named "Transfer".
        if (row.isTransfer) continue;
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

      // Same one-pass resolution for accounts. addAccount returns the created
      // model, so unlike categories this needs no re-find. A wallet named only
      // by a CSV has no opening balance, type or colour to restore — the
      // preview says so before the user confirms.
      final accountIds = <String, String>{};
      Future<String> accountIdFor(String? name) async {
        if (name == null) return _accountId!;
        final key = accountKey(name);
        final known = accountIds[key];
        if (known != null) return known;

        AccountModel? existing;
        for (final a in accountProvider.accounts) {
          if (accountKey(a.name) == key) {
            existing = a;
            break;
          }
        }
        final account =
            existing ??
            await accountProvider.addAccount(
              name: name,
              type: 'cash',
              openingBalance: 0,
              color: AppColors.swatchOptions.first,
            );
        accountIds[key] = account.id;
        return account.id;
      }

      for (final row in _rows) {
        final accountId = await accountIdFor(row.accountName);

        if (row.isTransfer) {
          // Rebuilt as the app builds them: two legs sharing one transferId,
          // both flagged isTransfer so every income/expense aggregate skips
          // them, both on the system category. The shared id is what lets
          // deleting either leg take the other with it.
          final transferId = _uuid.v4();
          final toAccountId = await accountIdFor(row.toAccountName);
          for (final leg in [
            (type: 'expense', account: accountId),
            (type: 'income', account: toAccountId),
          ]) {
            toInsert.add(
              TransactionModel(
                id: _uuid.v4(),
                type: leg.type,
                amount: row.amount,
                categoryId: SeedData.transferCategoryId,
                accountId: leg.account,
                transferId: transferId,
                isTransfer: true,
                date: row.date,
                note: row.note,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
          continue;
        }

        final name = row.categoryName ?? loc.importedCategoryName;
        toInsert.add(
          TransactionModel(
            id: _uuid.v4(),
            type: row.type,
            amount: row.amount,
            categoryId: categoryIds[categoryKey(row.type, name)]!,
            accountId: accountId,
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

      // The row count, not toInsert.length: the button the user pressed said
      // rows, and a confirmation reporting a larger number reads as duplication.
      if (mounted) Navigator.of(context).pop(_rows.length);
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
                loc.csvColumnAccount,
                _accountCol,
                required: false,
                onChanged: (v) => setState(() => _accountCol = v),
              ),
              _columnDropdown(
                loc.csvColumnToAccount,
                _toAccountCol,
                required: false,
                onChanged: (v) => setState(() => _toAccountCol = v),
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
              // The one place the row/entry gap is stated. Without it the
              // ledger simply grows by more rows than the file had, which
              // reads as the import duplicating the transfers.
              if (_transferRowCount > 0) ...[
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  loc.csvTransferExpansionNote(_transferRowCount, _entryCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // A CSV carries an account's name and nothing else, so a wallet
              // created from one cannot reproduce the balance it had on the
              // other phone. Say it here rather than let the user discover it
              // after the import.
              if (_newAccounts.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  loc.csvNewAccountsNote(_newAccounts.join(', ')),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  loc.csvNewAccountsCaveat,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
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
                  : Text(loc.confirmImportRows(_rows.length)),
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
    // A transfer is neither income nor expense — it will be excluded from
    // both totals once imported, so it must not be coloured as either.
    final amountColor = row.isTransfer
        ? theme.colorScheme.onSurfaceVariant
        : isIncome
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);
    final sign = row.isTransfer
        ? ''
        : isIncome
        ? '+ '
        : '- ';

    // For a transfer the useful thing to show is where the money goes, not a
    // category it does not really have.
    final title = row.isTransfer
        ? '${row.accountName ?? _fallbackAccountName(context)} → ${row.toAccountName}'
        : row.categoryName ?? loc.importedCategoryName;

    final details = [
      DateFormat.yMMMd().format(row.date),
      if (!row.isTransfer && row.accountName != null) row.accountName!,
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
          if (row.isTransfer)
            Padding(
              padding: const EdgeInsets.only(right: AppConstants.spacingSm),
              child: Icon(
                Icons.swap_horiz,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
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
            '$sign${NumberUtils.formatCurrency(row.amount, symbol: settings.currencySymbol, useDecimals: settings.currencyUseDecimals)}',
        style: AppTypography.amountStyle(color: amountColor, fontSize: 14),
      ),
    );
  }

  /// Name of the account the user picked, shown where a transfer row leaves
  /// its source blank and the fallback will be used.
  String _fallbackAccountName(BuildContext context) =>
      context.read<AccountProvider>().getAccountById(_accountId!)?.name ?? '';

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
