import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import 'transaction_tile.dart';

/// Calendar view over a given transaction list — a browsing tool, so it
/// takes the list as a parameter rather than reading a specific period
/// off a provider. Used as a view mode on the Records screen; previously
/// lived on the dashboard (as DashboardCalendar) where it only ever saw
/// whichever single period the dashboard had loaded.
class TransactionCalendar extends StatefulWidget {
  final List<TransactionModel> transactions;

  const TransactionCalendar({super.key, required this.transactions});

  @override
  State<TransactionCalendar> createState() => _TransactionCalendarState();
}

class _TransactionCalendarState extends State<TransactionCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _showTransactionsBottomSheet(selectedDay);
    }
  }

  void _showTransactionsBottomSheet(DateTime day) {
    final dayTransactions =
        widget.transactions.where((t) => isSameDay(t.date, day)).toList();
    final loc = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.9,
          initialChildSize: 0.5,
          builder: (context, scrollController) {
            if (dayTransactions.isEmpty) {
              return Center(
                child: Text(loc.noTransactionsOnThisDay, style: Theme.of(context).textTheme.bodyLarge),
              );
            }
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              itemCount: dayTransactions.length,
              itemBuilder: (context, index) {
                return TransactionTile(
                  transaction: dayTransactions[index],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    // Precompute daily totals
    final dailyTotals = <DateTime, double>{};
    for (final t in widget.transactions) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      final current = dailyTotals[date] ?? 0.0;
      dailyTotals[date] = current + (t.isIncome ? t.amount : -t.amount);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() => _calendarFormat = format);
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            final dateKey = DateTime(date.year, date.month, date.day);
            final total = dailyTotals[dateKey];
            if (total == null || total == 0) return const SizedBox();

            final isPositive = total > 0;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final color = isPositive
                ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
                : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

            return Positioned(
              bottom: 1,
              child: Text(
                NumberUtils.formatCompact(total.abs(), symbol: settings.currencySymbol),
                style: TextStyle(
                  fontSize: 8,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
