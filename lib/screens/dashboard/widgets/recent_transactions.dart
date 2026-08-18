import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../transactions/widgets/transaction_tile.dart';
import '../../transactions/add_transaction_screen.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/date_group_header.dart';
import '../../../widgets/section_card.dart';
import '../../../l10n/app_localizations.dart';

/// Recent transactions list on the dashboard — grouped by date.
class RecentTransactions extends StatelessWidget {
  const RecentTransactions({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionProvider>();

    final recentList = transactions.recentTransactions;
    final loc = AppLocalizations.of(context)!;

    if (recentList.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: loc.noRecentTransactions,
        subtitle: '',
        action: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddTransactionScreen(),
              fullscreenDialog: true,
            ),
          ),
          icon: const Icon(Icons.add),
          label: Text(loc.addTransactionCta),
        ),
      );
    }

    final grouped = transactions.getGroupedTransactions(recentList);

    return SectionCard(
      title: loc.recentTransactions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in grouped.entries) ...[
            DateGroupHeader(date: entry.key, transactions: entry.value),
            ...entry.value.map(
              (tx) => TransactionTile(transaction: tx, dense: true),
            ),
          ],
        ],
      ),
    );
  }
}
