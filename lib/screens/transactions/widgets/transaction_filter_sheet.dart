import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/account_provider.dart';
import '../../../models/category_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';

/// Immutable filter state for the Records screen. `dateRange == null`
/// means "any time" — the screen falls back to whatever list it was
/// given rather than filtering by date at all.
class TransactionFilter {
  final DateTimeRange? dateRange;
  final String type; // 'all' | 'income' | 'expense'
  final Set<String> categoryIds;
  final Set<String> accountIds;
  final double? minAmount;
  final double? maxAmount;

  const TransactionFilter({
    this.dateRange,
    this.type = 'all',
    this.categoryIds = const {},
    this.accountIds = const {},
    this.minAmount,
    this.maxAmount,
  });

  bool get isActive =>
      dateRange != null ||
      type != 'all' ||
      categoryIds.isNotEmpty ||
      accountIds.isNotEmpty ||
      minAmount != null ||
      maxAmount != null;

  TransactionFilter copyWith({
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    String? type,
    Set<String>? categoryIds,
    Set<String>? accountIds,
    double? minAmount,
    bool clearMinAmount = false,
    double? maxAmount,
    bool clearMaxAmount = false,
  }) {
    return TransactionFilter(
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      type: type ?? this.type,
      categoryIds: categoryIds ?? this.categoryIds,
      accountIds: accountIds ?? this.accountIds,
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
    );
  }
}

enum _DatePreset { thisPeriod, lastPeriod, last3Months, custom, any }

/// Bottom sheet for building a [TransactionFilter]. Returns the new filter
/// via `Navigator.pop`, or null if dismissed without applying.
class TransactionFilterSheet extends StatefulWidget {
  final TransactionFilter initial;
  final ({DateTime start, DateTime end}) currentPeriod;
  final ({DateTime start, DateTime end}) previousPeriod;

  const TransactionFilterSheet({
    super.key,
    required this.initial,
    required this.currentPeriod,
    required this.previousPeriod,
  });

  static Future<TransactionFilter?> show(
    BuildContext context, {
    required TransactionFilter initial,
    required ({DateTime start, DateTime end}) currentPeriod,
    required ({DateTime start, DateTime end}) previousPeriod,
  }) {
    return showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionFilterSheet(
        initial: initial,
        currentPeriod: currentPeriod,
        previousPeriod: previousPeriod,
      ),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late TransactionFilter _filter;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;
    _minController = TextEditingController(
      text: _filter.minAmount != null ? _filter.minAmount!.toStringAsFixed(0) : '',
    );
    _maxController = TextEditingController(
      text: _filter.maxAmount != null ? _filter.maxAmount!.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  _DatePreset get _activePreset {
    final r = _filter.dateRange;
    if (r == null) return _DatePreset.any;
    if (_sameRange(r, widget.currentPeriod)) return _DatePreset.thisPeriod;
    if (_sameRange(r, widget.previousPeriod)) return _DatePreset.lastPeriod;
    final now = DateTime.now();
    final last3 = DateTime(now.year, now.month - 3, now.day);
    if (_sameDay(r.start, last3) && _sameDay(r.end, now)) return _DatePreset.last3Months;
    return _DatePreset.custom;
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _sameRange(DateTimeRange r, ({DateTime start, DateTime end}) period) =>
      _sameDay(r.start, period.start) && _sameDay(r.end, period.end);

  void _pickPreset(_DatePreset preset) async {
    switch (preset) {
      case _DatePreset.any:
        setState(() => _filter = _filter.copyWith(clearDateRange: true));
        return;
      case _DatePreset.thisPeriod:
        setState(() => _filter = _filter.copyWith(
              dateRange: DateTimeRange(start: widget.currentPeriod.start, end: widget.currentPeriod.end),
            ));
        return;
      case _DatePreset.lastPeriod:
        setState(() => _filter = _filter.copyWith(
              dateRange: DateTimeRange(start: widget.previousPeriod.start, end: widget.previousPeriod.end),
            ));
        return;
      case _DatePreset.last3Months:
        final now = DateTime.now();
        setState(() => _filter = _filter.copyWith(
              dateRange: DateTimeRange(start: DateTime(now.year, now.month - 3, now.day), end: now),
            ));
        return;
      case _DatePreset.custom:
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(DateTime.now().year - 5),
          lastDate: DateTime(DateTime.now().year + 5),
          initialDateRange: _filter.dateRange,
        );
        if (picked != null) {
          setState(() => _filter = _filter.copyWith(dateRange: picked));
        }
        return;
    }
  }

  void _toggleCategory(String id) {
    final updated = Set<String>.from(_filter.categoryIds);
    if (!updated.add(id)) updated.remove(id);
    setState(() => _filter = _filter.copyWith(categoryIds: updated));
  }

  /// Switches the type and drops any category selection that type no longer
  /// shows. Without the pruning, an expense category picked under "All"
  /// would keep filtering the results after switching to Income, with no
  /// chip left on screen to explain why nothing matches.
  void _setType(String type, List<CategoryModel> visible) {
    final visibleIds = visible.map((c) => c.id).toSet();
    setState(() => _filter = _filter.copyWith(
          type: type,
          categoryIds: _filter.categoryIds.intersection(visibleIds),
        ));
  }

  void _toggleAccount(String id) {
    final updated = Set<String>.from(_filter.accountIds);
    if (!updated.add(id)) updated.remove(id);
    setState(() => _filter = _filter.copyWith(accountIds: updated));
  }

  void _apply() {
    final min = double.tryParse(_minController.text);
    final max = double.tryParse(_maxController.text);
    Navigator.of(context).pop(
      _filter.copyWith(
        minAmount: min,
        clearMinAmount: min == null,
        maxAmount: max,
        clearMaxAmount: max == null,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _filter = const TransactionFilter();
      _minController.clear();
      _maxController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    // The type-scoped getters, not the raw list: they drop archived and
    // system rows, so the internal "Transfer" category stops showing up as
    // something you can filter by. The two remaining "Other" chips are the
    // real expense and income categories of that name — telling them apart
    // is what the type sections below are for.
    final categoryProvider = context.watch<CategoryProvider>();
    final expenseCategories = categoryProvider.expenseCategories;
    final incomeCategories = categoryProvider.incomeCategories;
    final accounts = context.watch<AccountProvider>().activeAccounts;
    final preset = _activePreset;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppConstants.spacingLg),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(loc.filters, style: theme.textTheme.titleLarge),
                  TextButton(onPressed: _clearAll, child: Text(loc.clearFilters)),
                ],
              ),
              const SizedBox(height: AppConstants.spacingMd),

              Text(loc.dateRange, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: AppConstants.spacingSm,
                runSpacing: AppConstants.spacingSm,
                children: [
                  _PresetChip(
                    label: loc.anyTime,
                    isSelected: preset == _DatePreset.any,
                    onTap: () => _pickPreset(_DatePreset.any),
                  ),
                  _PresetChip(
                    label: loc.thisPeriod,
                    isSelected: preset == _DatePreset.thisPeriod,
                    onTap: () => _pickPreset(_DatePreset.thisPeriod),
                  ),
                  _PresetChip(
                    label: loc.lastPeriod,
                    isSelected: preset == _DatePreset.lastPeriod,
                    onTap: () => _pickPreset(_DatePreset.lastPeriod),
                  ),
                  _PresetChip(
                    label: loc.last3Months,
                    isSelected: preset == _DatePreset.last3Months,
                    onTap: () => _pickPreset(_DatePreset.last3Months),
                  ),
                  _PresetChip(
                    label: loc.customRange,
                    isSelected: preset == _DatePreset.custom,
                    onTap: () => _pickPreset(_DatePreset.custom),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              Text(loc.type, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppConstants.spacingSm),
              Wrap(
                spacing: AppConstants.spacingSm,
                children: [
                  _PresetChip(
                    label: loc.all,
                    isSelected: _filter.type == 'all',
                    onTap: () => _setType('all', [...expenseCategories, ...incomeCategories]),
                  ),
                  _PresetChip(
                    label: loc.expense,
                    isSelected: _filter.type == 'expense',
                    onTap: () => _setType('expense', expenseCategories),
                  ),
                  _PresetChip(
                    label: loc.income,
                    isSelected: _filter.type == 'income',
                    onTap: () => _setType('income', incomeCategories),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingLg),

              Text(loc.category, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppConstants.spacingSm),
              // Scoped to the type above, so picking "Expense" can't leave
              // income categories on offer. Under "All" both are listed, but
              // split and labelled — that is the only place the expense and
              // income "Other" appear together, and unlabelled they read as
              // a duplicate.
              if (_filter.type != 'income')
                _CategorySection(
                  label: _filter.type == 'all' ? loc.expense : null,
                  categories: expenseCategories,
                  selectedIds: _filter.categoryIds,
                  onToggle: _toggleCategory,
                ),
              if (_filter.type == 'all') const SizedBox(height: AppConstants.spacingMd),
              if (_filter.type != 'expense')
                _CategorySection(
                  label: _filter.type == 'all' ? loc.income : null,
                  categories: incomeCategories,
                  selectedIds: _filter.categoryIds,
                  onToggle: _toggleCategory,
                ),
              const SizedBox(height: AppConstants.spacingLg),

              if (accounts.isNotEmpty) ...[
                Text(loc.account, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppConstants.spacingSm),
                Wrap(
                  spacing: AppConstants.spacingSm,
                  runSpacing: AppConstants.spacingSm,
                  children: accounts.map((a) {
                    return _PresetChip(
                      label: a.name,
                      isSelected: _filter.accountIds.contains(a.id),
                      onTap: () => _toggleAccount(a.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppConstants.spacingLg),
              ],

              Text(loc.amountRange, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppConstants.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: loc.minAmount),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: loc.maxAmount),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _apply,
                  child: Text(loc.applyFilters),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One type's worth of category chips, under an optional type label. The
/// label is only drawn when both sections are on screen at once — with a
/// single section the "Category" heading above already says everything.
class _CategorySection extends StatelessWidget {
  final String? label;
  final List<CategoryModel> categories;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _CategorySection({
    required this.label,
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
        ],
        Wrap(
          spacing: AppConstants.spacingSm,
          runSpacing: AppConstants.spacingSm,
          children: categories
              .map((c) => _PresetChip(
                    label: c.name,
                    isSelected: selectedIds.contains(c.id),
                    onTap: () => onToggle(c.id),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }
}
