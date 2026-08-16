import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../models/recurring_transaction_model.dart';
import '../../models/transaction_model.dart';
import '../../repositories/recurring_repository.dart';
import '../database/database_helper.dart';
import '../database/seed_data.dart';
import 'notification_service.dart';

/// Service that checks for due recurring transactions on app launch,
/// generates the missing transaction entries, and keeps subscription
/// reminder notifications in sync with whatever it just generated.
class RecurringService {
  final RecurringRepository _recurringRepo;
  final NotificationService _notificationService;
  static const _uuid = Uuid();

  RecurringService({
    RecurringRepository? recurringRepo,
    NotificationService? notificationService,
  })  : _recurringRepo = recurringRepo ?? RecurringRepository(),
        _notificationService = notificationService ?? NotificationService.instance;

  /// Safety cap on occurrences caught up per template in one run — guards
  /// against a runaway loop for a daily template left active for years
  /// without the app being opened.
  static const _maxCatchUpPerTemplate = 500;

  /// Process all active recurring transactions and generate any entries
  /// due since the last run. Each template's catch-up runs inside one
  /// database transaction: either every due occurrence for that template
  /// lands, or none of them do. Re-running this after a crash (or twice in
  /// a row) is a no-op, backed by the unique index on
  /// transactions(recurringId, date).
  Future<int> processRecurringTransactions() async {
    List<RecurringTransactionModel> activeRecurring;
    try {
      activeRecurring = await _recurringRepo.getActive();
    } catch (e) {
      debugPrint('Failed to load active recurring transactions: $e');
      return 0;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    var generatedCount = 0;

    for (final recurring in activeRecurring) {
      // A paused template (e.g. a subscription on hold) keeps its
      // lastRunDate frozen rather than generating charges for the time it
      // was off — resuming it moves lastRunDate forward instead of
      // backfilling the gap (see RecurringProvider.resumeRecurring).
      if (recurring.isPaused) continue;
      try {
        generatedCount += await _processOne(recurring, todayDate);
      } catch (e) {
        debugPrint('Failed to process recurring transaction ${recurring.id}: $e');
      }
    }

    await _rescheduleReminders();
    return generatedCount;
  }

  /// Re-syncs every subscription's reminder notification against its
  /// (possibly just-advanced) next occurrence. Re-fetches rather than
  /// reusing the list above since [_processOne] may have moved
  /// `lastRunDate` — and therefore `nextOccurrence` — forward.
  Future<void> _rescheduleReminders() async {
    if (!_notificationService.isSupported) return;
    try {
      final active = await _recurringRepo.getActive();
      for (final recurring in active) {
        if (recurring.isSubscription) {
          await _notificationService.scheduleReminder(recurring);
        }
      }
    } catch (e) {
      debugPrint('Failed to reschedule subscription reminders: $e');
    }
  }

  Future<int> _processOne(
    RecurringTransactionModel recurring,
    DateTime todayDate,
  ) async {
    if (recurring.endDate != null && todayDate.isAfter(recurring.endDate!)) {
      return 0;
    }

    final due = <TransactionModel>[];
    var next = recurring.nextOccurrence;
    while (!next.isAfter(todayDate)) {
      if (recurring.endDate != null && next.isAfter(recurring.endDate!)) break;
      due.add(_materialize(recurring, next));
      next = recurring.advanceFrom(next);
      if (due.length >= _maxCatchUpPerTemplate) break;
    }
    if (due.isEmpty) return 0;

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final t in due) {
        // ConflictAlgorithm.ignore + the partial unique index on
        // (recurringId, date) makes a repeated run a no-op instead of
        // posting duplicate transactions.
        batch.insert(
          'transactions',
          t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
      await txn.update(
        'recurring_transactions',
        {'lastRunDate': due.last.date.toIso8601String().substring(0, 10)},
        where: 'id = ?',
        whereArgs: [recurring.id],
      );
    });

    return due.length;
  }

  TransactionModel _materialize(
    RecurringTransactionModel recurring,
    DateTime date,
  ) {
    final now = DateTime.now();
    return TransactionModel(
      id: _uuid.v4(),
      type: recurring.type,
      amount: recurring.amount,
      categoryId: recurring.categoryId,
      // Templates created before accounts existed have no accountId —
      // fall back to the same default account every pre-v3 transaction
      // was backfilled into, so a catch-up run never fails to post.
      accountId: recurring.accountId ?? SeedData.defaultAccountId,
      // Was omitted, so only the first occurrence — the one the entry form
      // posts inline — ever carried a merchant. Every auto-generated one
      // landed with merchant NULL and then vanished from Top Merchants, the
      // merchant autocomplete and subscription detection, all three of which
      // filter on `merchant IS NOT NULL`. Migration v10 backfills the rows
      // already posted without it.
      merchant: recurring.merchant,
      date: date,
      note: recurring.note,
      recurringId: recurring.id,
      createdAt: now,
      updatedAt: now,
    );
  }
}
