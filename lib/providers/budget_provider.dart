import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../repositories/budget_repository.dart';
import '../repositories/transaction_repository.dart';
import '../core/services/budget_rollover_service.dart';
import '../core/utils/budget_leftover.dart';
import '../core/utils/date_utils.dart';
import '../core/constants/app_constants.dart';

enum BudgetAlertType { exceeded, warning }

class BudgetAlertResult {
  final BudgetAlertType type;
  final String percentage;

  BudgetAlertResult({required this.type, this.percentage = ''});
}

/// Budget spending data for a single budget (whatever its scope).
class BudgetStatus {
  final BudgetModel budget;
  final double spent;
  final double rolloverAmount;

  /// The date range [spent] was measured over. Carried on the status so
  /// pace bars and dashboard cards read the same range the number came
  /// from — recomputing it widget-side would silently disagree for a
  /// one-off budget, which is pinned to its creation period rather than
  /// to today's.
  final ({DateTime start, DateTime end}) period;

  const BudgetStatus({
    required this.budget,
    required this.spent,
    required this.period,
    this.rolloverAmount = 0,
  });

  /// The limit that actually applies to this period, once rollover from
  /// prior periods is folded in — this is what [ratio]/[remaining] measure
  /// against, not the budget's flat [BudgetModel.amount].
  double get effectiveAmount => budget.amount + rolloverAmount;

  double get ratio => effectiveAmount > 0 ? spent / effectiveAmount : 0;
  double get remaining => (effectiveAmount - spent).clamp(0, double.infinity);
  bool get isWarning =>
      ratio >= AppConstants.budgetWarningThreshold && ratio < AppConstants.budgetExceededThreshold;
  bool get isExceeded => ratio > AppConstants.budgetExceededThreshold;
  bool get isNormal => ratio < AppConstants.budgetWarningThreshold;
}

/// An ended one-off budget that still has unspent money the user hasn't
/// decided about.
///
/// Separate from [BudgetStatus] rather than folded into it: statuses exist
/// only for active budgets and describe a *live* period the user can still
/// spend against, whereas this describes a closed one. Sharing the type
/// would mean every consumer of `budgetStatuses` had to start asking
/// whether the budget behind it was still running.
class BudgetLeftover {
  final BudgetModel budget;
  final double spent;

  /// Unspent money, from [computeBudgetLeftover] — always greater than zero
  /// for anything that reaches the UI.
  final double leftover;

  /// The period the budget covered, kept for the same reason
  /// [BudgetStatus.period] is: it dates the "mark as spent" transaction so
  /// the expense lands in the period being settled rather than today's.
  final ({DateTime start, DateTime end}) period;

  const BudgetLeftover({
    required this.budget,
    required this.spent,
    required this.leftover,
    required this.period,
  });
}

/// Manages budget state — CRUD + spending calculations.
class BudgetProvider extends ChangeNotifier {
  final BudgetRepository _repository;
  final TransactionRepository _transactionRepo;
  final BudgetRolloverService _rolloverService;
  static const _uuid = Uuid();

  BudgetProvider({
    BudgetRepository? repository,
    TransactionRepository? transactionRepo,
    BudgetRolloverService? rolloverService,
  })  : _repository = repository ?? BudgetRepository(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _rolloverService = rolloverService ?? BudgetRolloverService();

  /// How many leftover prompts [_calculateLeftovers] will surface at once.
  /// The prompt is a nudge rather than a ledger — a user sitting on a
  /// backlog doesn't need all of it on screen. Newest first, so the cap
  /// drops the stalest.
  static const _maxLeftoverPrompts = 5;

  /// How many ended budgets [_calculateLeftovers] will price up looking for
  /// those prompts. Each costs a spend query, so the walk needs a bound.
  ///
  /// Separate from [_maxLeftoverPrompts] because most candidates produce no
  /// prompt: a budget spent to the last cent is never resolved — there was
  /// nothing to ask — so it stays a candidate forever. Capping candidates
  /// instead of results would let a handful of those permanently crowd out
  /// every newer budget that does have money left.
  static const _maxLeftoverScan = 30;

  List<BudgetModel> _budgets = [];
  Map<String, BudgetStatus> _budgetStatuses = {}; // keyed by budget.id
  List<BudgetLeftover> _pendingLeftovers = [];
  bool _isLoading = false;
  String? _error;

  List<BudgetModel> get budgets => _budgets;
  Map<String, BudgetStatus> get budgetStatuses => _budgetStatuses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Ended one-off budgets with unspent money awaiting the user's decision,
  /// most recently ended first.
  List<BudgetLeftover> get pendingLeftovers => _pendingLeftovers;

  List<BudgetModel> get activeBudgets =>
      _budgets.where((b) => b.isActive).toList();

  /// One-off budgets that have run their course — retired by
  /// `BudgetExpiryService` rather than deleted, so the user sees them wind
  /// down instead of silently vanishing at the period boundary.
  ///
  /// Deliberately excludes recurring budgets a user deactivated by other
  /// means; those aren't "ended", they're switched off.
  List<BudgetModel> get endedBudgets =>
      _budgets.where((b) => !b.isActive && !b.isRecurring).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Load budgets and calculate spending for each.
  Future<void> loadBudgets({required int payday}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _budgets = await _repository.getAll();
      await _calculateStatuses(payday);
      await _calculateLeftovers(payday);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recalculate every active budget's spending status for its own
  /// current period (periods can differ per budget: weekly or monthly).
  Future<void> _calculateStatuses(int payday) async {
    final statuses = <String, BudgetStatus>{};

    for (final budget in _budgets.where((b) => b.isActive)) {
      final period = _periodFor(budget, payday);
      final spent = await _spentFor(budget, period.start, period.end);
      final rollover = await _rolloverService.getCarriedAmount(budget, payday: payday);
      statuses[budget.id] =
          BudgetStatus(budget: budget, spent: spent, period: period, rolloverAmount: rollover);
    }

    _budgetStatuses = statuses;
  }

  /// Price up the ended one-off budgets that still owe the user a decision
  /// about their unspent money.
  ///
  /// Runs after [_calculateStatuses] and covers the budgets that one skips:
  /// statuses are built for active budgets only, so before this there was
  /// no spent figure anywhere in the app for a budget that had ended, and
  /// the leftover was invisible by construction.
  ///
  /// Candidates are filtered on the cheap fields *before* the spend query,
  /// so an install with years of resolved budgets behind it pays nothing.
  Future<void> _calculateLeftovers(int payday) async {
    final candidates = _budgets
        .where((b) => !b.isActive && !b.isRecurring && b.leftoverResolvedAt == null)
        .toList()
      // Newest first — `updatedAt` is the moment BudgetExpiryService
      // retired the budget, which is exactly when it ended.
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final leftovers = <BudgetLeftover>[];
    for (final budget in candidates.take(_maxLeftoverScan)) {
      if (leftovers.length >= _maxLeftoverPrompts) break;

      final period = _periodFor(budget, payday);
      final spent = await _spentFor(budget, period.start, period.end);
      final leftover = computeBudgetLeftover(amount: budget.amount, spent: spent);

      if (!needsLeftoverPrompt(
        isActive: budget.isActive,
        isRecurring: budget.isRecurring,
        leftoverResolvedAt: budget.leftoverResolvedAt,
        leftover: leftover,
      )) {
        continue;
      }

      leftovers.add(BudgetLeftover(
        budget: budget,
        spent: spent,
        leftover: leftover,
        period: period,
      ));
    }

    _pendingLeftovers = leftovers;
  }

  /// Record that the user has answered the leftover prompt for [budgetId],
  /// whichever option they picked — including dismissing it.
  Future<void> resolveLeftover(String budgetId) async {
    final resolvedAt = DateTime.now();
    await _repository.markLeftoverResolved(budgetId, at: resolvedAt);

    final index = _budgets.indexWhere((b) => b.id == budgetId);
    if (index != -1) {
      _budgets[index] = _budgets[index].copyWith(leftoverResolvedAt: resolvedAt);
    }
    _pendingLeftovers =
        _pendingLeftovers.where((l) => l.budget.id != budgetId).toList();
    notifyListeners();
  }

  /// Recreate an ended budget in the current period, worth its original
  /// limit plus whatever it didn't spend.
  ///
  /// The new budget is a fresh one-off: its `createdAt` is now, which is
  /// what pins it to the current period (budgets carry no period anchor of
  /// their own). Staying one-off means it will ask the same question again
  /// when *it* ends, rather than quietly committing the user to a budget
  /// that renews forever — they chose "roll this forward", not "make this
  /// permanent".
  ///
  /// Throws [StateError] when one of the categories has since been given
  /// another active budget; rolling forward anyway would leave the category
  /// covered twice, which the rest of the app assumes cannot happen (see
  /// [getStatusForCategory]).
  Future<void> rollForwardLeftover(
    BudgetLeftover leftover, {
    required int payday,
  }) async {
    final budget = leftover.budget;
    final conflict = budget.categoryIds.any(isCategoryBudgeted);
    if (conflict) {
      throw StateError('A category in this budget is already budgeted');
    }

    await addBudget(
      name: budget.name,
      amount: rollForwardAmount(
        budgetAmount: budget.amount,
        leftover: leftover.leftover,
      ),
      period: budget.period,
      rolloverMode: budget.rolloverMode,
      scope: budget.scope,
      categoryIds: budget.categoryIds,
      payday: payday,
      isRecurring: false,
    );
    await resolveLeftover(budget.id);
  }

  /// Whether an active budget already covers [categoryId].
  ///
  /// A category is meant to be covered by at most one budget — several
  /// places rely on it, [getStatusForCategory] most directly. Lives here
  /// rather than in the form because the form is no longer the only thing
  /// that creates budgets: [rollForwardLeftover] needs the same guard.
  ///
  /// [excludingBudgetId] is for the edit case, where the budget being
  /// edited shouldn't count as a conflict with itself.
  bool isCategoryBudgeted(String categoryId, {String? excludingBudgetId}) {
    return _budgets.any((b) =>
        b.id != excludingBudgetId && b.isActive && b.categoryIds.contains(categoryId));
  }

  /// The date range [budget] measures spending over.
  ///
  /// A recurring budget always means "right now". A one-off budget stays
  /// pinned to the period it was created in, so it still reports the right
  /// numbers if the app wasn't opened before `BudgetExpiryService` could
  /// retire it — otherwise it would silently start measuring against a
  /// period it was never meant to cover.
  ({DateTime start, DateTime end}) _periodFor(BudgetModel budget, int payday) {
    return AppDateUtils.getCurrentPeriodFor(
      budget.period,
      payday,
      referenceDate: budget.isRecurring ? null : budget.createdAt,
    );
  }

  /// What [budget] has spent in a range. Paired with [transactionsFor]:
  /// whatever this counts, that must list, or the detail screen shows a
  /// total its own transactions don't add up to. Change one, change both.
  Future<double> _spentFor(BudgetModel budget, DateTime start, DateTime end) {
    if (budget.scope == 'overall') {
      return _transactionRepo.getSumByTypeAndDateRange('expense', start, end);
    }
    return _transactionRepo.getCategoriesSumByDateRange(budget.categoryIds, start, end);
  }

  /// The transactions behind [BudgetStatus.spent] — the rows [_spentFor]
  /// summed, newest first.
  ///
  /// Fetched on demand rather than held in [_budgetStatuses]: only the
  /// detail screen needs the rows, and caching a list per budget would mean
  /// re-loading every budget's transactions on each `loadBudgets`.
  ///
  /// Takes the period from the caller's [BudgetStatus] instead of
  /// recomputing it, for the reason spelled out on [BudgetStatus.period] —
  /// a one-off budget is pinned to its creation period, not today's.
  Future<List<TransactionModel>> transactionsFor(
    BudgetModel budget, {
    required ({DateTime start, DateTime end}) period,
  }) {
    if (budget.scope == 'overall') {
      return _transactionRepo.getByTypeAndDateRange('expense', period.start, period.end);
    }
    return _transactionRepo.getCategoriesByDateRange(
      budget.categoryIds,
      period.start,
      period.end,
    );
  }

  /// The status of whichever active budget covers [categoryId] — a
  /// category-scoped budget for it directly, or a group budget that
  /// includes it. A category can only be covered by one budget in
  /// practice (the form prevents double-assignment), so the first match
  /// is authoritative.
  BudgetStatus? getStatusForCategory(String categoryId) {
    for (final status in _budgetStatuses.values) {
      if (status.budget.scope != 'overall' && status.budget.categoryIds.contains(categoryId)) {
        return status;
      }
    }
    return null;
  }

  /// Get the first N budget statuses (ordered by creation date).
  List<BudgetStatus> getTopStatuses(int count) {
    final statuses = _budgets
        .where((b) => b.isActive)
        .map((b) => _budgetStatuses[b.id])
        .where((s) => s != null)
        .cast<BudgetStatus>()
        .toList();
    return statuses.take(count).toList();
  }

  /// Check if adding an expense would cross a budget threshold — checks
  /// whichever budget (category or group) covers [categoryId], plus any
  /// active overall budget.
  BudgetAlertResult? checkBudgetAlert(String categoryId, double additionalAmount, int payday) {
    final status = getStatusForCategory(categoryId) ??
        _budgetStatuses.values.where((s) => s.budget.scope == 'overall').firstOrNull;
    if (status == null) return null;

    final newSpent = status.spent + additionalAmount;
    final newRatio = status.effectiveAmount > 0 ? newSpent / status.effectiveAmount : 0;

    // Use amount comparison to avoid floating point precision issues near 1.0
    if (newSpent > status.effectiveAmount && status.spent <= status.effectiveAmount) {
      return BudgetAlertResult(type: BudgetAlertType.exceeded);
    }

    if (newRatio >= AppConstants.budgetWarningThreshold &&
        status.ratio < AppConstants.budgetWarningThreshold) {
      final pct = (newRatio * 100).toStringAsFixed(0);
      return BudgetAlertResult(type: BudgetAlertType.warning, percentage: pct);
    }
    return null;
  }

  Future<void> addBudget({
    String? name,
    required double amount,
    String period = 'monthly',
    String rolloverMode = 'none',
    required String scope,
    required List<String> categoryIds,
    required int payday,
    bool isRecurring = false,
  }) async {
    try {
      final now = DateTime.now();
      final budget = BudgetModel(
        id: _uuid.v4(),
        name: name,
        amount: amount,
        period: period,
        rolloverMode: rolloverMode,
        scope: scope,
        categoryIds: scope == 'overall' ? const [] : categoryIds,
        isActive: true,
        isRecurring: isRecurring,
        createdAt: now,
        updatedAt: now,
      );

      await _repository.insert(budget);
      _budgets.add(budget);

      final periodRange = _periodFor(budget, payday);
      final spent = await _spentFor(budget, periodRange.start, periodRange.end);
      final rollover = await _rolloverService.getCarriedAmount(budget, payday: payday);
      _budgetStatuses[budget.id] =
          BudgetStatus(budget: budget, spent: spent, period: periodRange, rolloverAmount: rollover);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateBudget(BudgetModel budget, {required int payday}) async {
    try {
      final updated = budget.copyWith(updatedAt: DateTime.now());
      await _repository.update(updated);
      final index = _budgets.indexWhere((b) => b.id == updated.id);
      if (index != -1) {
        _budgets[index] = updated;

        final periodRange = _periodFor(updated, payday);
        final spent = await _spentFor(updated, periodRange.start, periodRange.end);
        final rollover = await _rolloverService.getCarriedAmount(updated, payday: payday);
        _budgetStatuses[updated.id] = BudgetStatus(
            budget: updated, spent: spent, period: periodRange, rolloverAmount: rollover);

        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteBudget(String id) async {
    try {
      await _repository.delete(id);

      final index = _budgets.indexWhere((b) => b.id == id);
      if (index != -1) {
        _budgetStatuses.remove(id);
        _budgets.removeAt(index);
        // Deleting an ended budget answers its leftover prompt by
        // removing the thing being asked about.
        _pendingLeftovers =
            _pendingLeftovers.where((l) => l.budget.id != id).toList();
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
