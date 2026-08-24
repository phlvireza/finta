import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/goal_model.dart';
import '../../models/transaction_model.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/date_group_header.dart';
import '../../widgets/squi/squi_state.dart';
import '../../core/constants/squi.dart';
import '../../widgets/error_state.dart';
import '../../widgets/skeleton_box.dart';
import '../../widgets/section_card.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/widgets/transaction_tile.dart';
import 'goal_actions.dart';
import 'goals_list_screen.dart';
import 'widgets/contribute_to_goal_sheet.dart';
import 'widgets/goal_progress_summary.dart';
import '../../l10n/app_localizations.dart';

/// Everything behind one goal's progress bar: the same summary the card
/// shows, plus the contributions that produced the number.
///
/// The bar on its own only ever answered "how much" — this screen answers
/// "when, and out of which wallet", which is the question that follows it.
/// Contributions are ordinary transactions, so the rows here are the real
/// ones: tapping one opens it for editing, and the header moves when it does.
class GoalDetailScreen extends StatefulWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  List<TransactionModel>? _transactions;
  String? _error;

  /// The progress figure the loaded list belongs to. `GoalProvider` recomputes
  /// it from the tagged transactions on every `loadGoals`, so a changed total
  /// means a contribution was added, edited or removed and the list underneath
  /// it is stale. Edits that leave the total alone (a reworded note) are
  /// covered by the explicit reload in [_openTransaction].
  double? _loadedFor;

  /// Set for the frame between a confirmed delete and this route popping —
  /// without it the missing-goal branch in [build] would flash an error on
  /// the way out.
  bool _deleting = false;

  /// Runs on mount and again whenever [GoalProvider] notifies, because
  /// `build` watches it. Read (not watch) here — this is not a build method.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<GoalProvider>();
    if (provider.getGoalById(widget.goalId) == null) return;
    final progress = provider.progressOf(widget.goalId);
    if (_loadedFor != progress || _transactions == null) {
      _loadedFor = progress;
      _load();
    }
  }

  Future<void> _load() async {
    final provider = context.read<GoalProvider>();
    try {
      final items = await provider.transactionsFor(widget.goalId);
      if (!mounted) return;
      setState(() {
        _transactions = items;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Opens a contribution for editing. `AddTransactionScreen`'s own
  /// cross-provider refresh covers transactions, budgets, accounts and
  /// analytics but not goals, so reload the goal here — otherwise editing a
  /// contribution's amount would move the list without moving the header.
  Future<void> _openTransaction(TransactionModel transaction) async {
    final provider = context.read<GoalProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(editTransaction: transaction),
      ),
    );
    if (!mounted) return;
    await provider.loadGoals();
    if (!mounted) return;
    _loadedFor = provider.progressOf(widget.goalId);
    await _load();
  }

  Future<void> _delete(GoalModel goal) async {
    final navigator = Navigator.of(context);
    setState(() => _deleting = true);

    final deleted = await confirmDeleteGoal(context, goal);

    if (deleted) {
      navigator.pop();
    } else if (mounted) {
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final goal = context.watch<GoalProvider>().getGoalById(widget.goalId);

    // Deleting a goal with no contributions removes the row outright. A
    // delete started here is already on its way out, so it gets a blank
    // frame rather than an error it would see for an instant.
    if (goal == null) {
      if (_deleting) return const Scaffold(body: SizedBox.shrink());
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(title: loc.errorFailedToLoadData),
      );
    }

    final progress = context.watch<GoalProvider>().progressOf(goal.id);
    final isComplete = progress >= goal.targetAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: loc.editGoal,
            onPressed: () => GoalsListScreen.showGoalForm(context, goal: goal),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: theme.colorScheme.error,
            tooltip: loc.delete,
            onPressed: _deleting ? null : () => _delete(goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          AppConstants.spacingMd,
          AppConstants.spacingLg,
          AppConstants.fabClearance,
        ),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GoalProgressSummary(goal: goal),
                if (!isComplete) ...[
                  const SizedBox(height: AppConstants.spacingMd),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () =>
                          ContributeToGoalSheet.show(context, goal),
                      child: Text(loc.contribute),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(loc.contributions, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppConstants.spacingMd),
          ..._buildContributionSection(context, loc),
        ],
      ),
    );
  }

  List<Widget> _buildContributionSection(
    BuildContext context,
    AppLocalizations loc,
  ) {
    // Both branches below need an explicit height: they are children of a
    // scrolling ListView, so they are laid out unbounded, and neither a
    // ListView (the skeleton) nor a full-height Column (ErrorState) can size
    // itself in infinite space.
    if (_error != null) {
      return [
        SizedBox(
          height: 320,
          child: ErrorState(
            title: loc.errorFailedToLoadData,
            message: _error,
            onRetry: _load,
          ),
        ),
      ];
    }

    final transactions = _transactions;
    if (transactions == null) {
      return const [
        SizedBox(height: 320, child: SkeletonTransactionList(count: 4)),
      ];
    }

    if (transactions.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: AppConstants.spacingXl),
          child: SquiState(
            pose: SquiPose.empty,
            title: loc.squiEmptyContributions,
            subtitle: loc.squiEmptyContributionsBody,
          ),
        ),
      ];
    }

    final grouped = context.read<TransactionProvider>().getGroupedTransactions(
      transactions,
    );
    return grouped.entries
        .map(
          (entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateGroupHeader(date: entry.key, transactions: entry.value),
              ...entry.value.map(
                (tx) => TransactionTile(
                  transaction: tx,
                  dense: true,
                  onTap: () => _openTransaction(tx),
                ),
              ),
            ],
          ),
        )
        .toList();
  }
}
