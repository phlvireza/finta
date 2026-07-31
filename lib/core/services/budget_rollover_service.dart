import '../../models/budget_model.dart';
import '../../repositories/transaction_repository.dart';
import '../utils/date_utils.dart';

/// Computes how much of a rollover budget's unspent (or overspent) amount
/// carries into the current period.
///
/// Deliberately stateless / not persisted: the carry is recomputed from
/// actual transaction sums every time it's needed, walking back period by
/// period to the budget's creation date (capped). This costs a handful of
/// cheap SUM queries for a normal budget's age, in exchange for never
/// going stale — a persisted ledger would need explicit invalidation any
/// time a past transaction changes, which is exactly the kind of bug that
/// discovers itself in production months later.
class BudgetRolloverService {
  final TransactionRepository _transactionRepo;

  BudgetRolloverService({TransactionRepository? transactionRepo})
      : _transactionRepo = transactionRepo ?? TransactionRepository();

  /// Safety cap on how many periods back to walk — guards against a
  /// years-old weekly rollover budget turning into an unbounded loop.
  static const _maxLookback = 200;

  /// The amount to add to (or subtract from, if negative) a budget's flat
  /// [BudgetModel.amount] to get its effective limit for the current
  /// period. Always 0 for `rolloverMode == 'none'`.
  Future<double> getCarriedAmount(BudgetModel budget, {required int payday}) async {
    if (!budget.hasRollover) return 0;

    final createdDate = DateTime(budget.createdAt.year, budget.createdAt.month, budget.createdAt.day);
    final periods = <({DateTime start, DateTime end})>[];
    var period = AppDateUtils.getCurrentPeriodFor(budget.period, payday);

    for (var i = 0; i < _maxLookback; i++) {
      final previous = AppDateUtils.getPreviousPeriodFor(budget.period, period, payday);
      if (previous.end.isBefore(createdDate)) break;
      periods.insert(0, previous);
      period = previous;
    }

    var carry = 0.0;
    for (final p in periods) {
      final spent = await _spentForBudget(budget, p.start, p.end);
      carry = applyRolloverStep(
        previousCarry: carry,
        budgeted: budget.amount,
        spent: spent,
        rolloverMode: budget.rolloverMode,
      );
    }
    return carry;
  }

  Future<double> _spentForBudget(BudgetModel budget, DateTime start, DateTime end) {
    if (budget.scope == 'overall') {
      return _transactionRepo.getSumByTypeAndDateRange('expense', start, end);
    }
    return _transactionRepo.getCategoriesSumByDateRange(budget.categoryIds, start, end);
  }
}

/// One period's worth of rollover accumulation — pulled out as a pure
/// function so the carry-forward math (the part that actually needs to be
/// correct) is unit-testable without a database.
///
/// `rolloverMode == 'positive'` floors the result at 0 every step, so an
/// overspent period never creates a debt the next period has to dig out
/// of; `'full'` lets it go negative, reducing the next period's effective
/// budget.
double applyRolloverStep({
  required double previousCarry,
  required double budgeted,
  required double spent,
  required String rolloverMode,
}) {
  final delta = previousCarry + (budgeted - spent);
  return rolloverMode == 'positive' ? (delta < 0 ? 0 : delta) : delta;
}
