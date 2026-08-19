import 'package:flutter/foundation.dart';
import '../../repositories/budget_repository.dart';
import '../utils/budget_expiry.dart';
import '../utils/date_utils.dart';

/// Retires one-off budgets whose period has ended.
///
/// Runs once at launch, alongside the recurring-transaction catch-up, and
/// for the same reason: a budget's period can roll over while the app
/// isn't running, so the boundary has to be reconciled on the way back in
/// rather than watched for live.
///
/// Expired budgets are **deactivated, never deleted**. Keeping the row
/// means the user can still see what they set and remove it deliberately,
/// and it frees the category for a new budget — `BudgetForm`'s
/// double-assignment check only considers active budgets.
class BudgetExpiryService {
  final BudgetRepository _budgetRepo;

  BudgetExpiryService({BudgetRepository? budgetRepo})
      : _budgetRepo = budgetRepo ?? BudgetRepository();

  /// Deactivate every active non-recurring budget whose period has passed.
  /// Returns how many were retired.
  ///
  /// Never throws: this sits on the startup path, and a budget that fails
  /// to retire is a far smaller problem than an app that won't open. The
  /// next launch retries it anyway, since the check is derived from
  /// `createdAt` rather than from a "last swept" marker.
  Future<int> expireFinishedBudgets({
    required int payday,
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();

    try {
      final active = await _budgetRepo.getActive();
      var expiredCount = 0;

      for (final budget in active) {
        if (budget.isRecurring) continue;

        final originPeriod = AppDateUtils.getCurrentPeriodFor(
          budget.period,
          payday,
          referenceDate: budget.createdAt,
        );

        if (!isBudgetExpired(
          isRecurring: budget.isRecurring,
          originPeriod: originPeriod,
          today: now,
        )) {
          continue;
        }

        try {
          await _budgetRepo.deactivate(budget.id, updatedAt: now);
          expiredCount++;
        } catch (e) {
          // One stubborn row shouldn't stop the rest from retiring.
          if (kDebugMode) debugPrint('Failed to expire budget ${budget.id}: $e');
        }
      }

      return expiredCount;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to expire finished budgets: $e');
      return 0;
    }
  }
}
