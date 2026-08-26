import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/recurring_transaction_model.dart';
import '../repositories/recurring_repository.dart';
import '../core/services/notification_service.dart';

/// Manages recurring transaction templates — CRUD + state, plus the
/// subscription-specific actions (pause/resume, reminder settings) that
/// build on the same templates.
class RecurringProvider extends ChangeNotifier {
  final RecurringRepository _repository;
  final NotificationService _notificationService;
  static const _uuid = Uuid();

  RecurringProvider({
    RecurringRepository? repository,
    NotificationService? notificationService,
  })  : _repository = repository ?? RecurringRepository(),
        _notificationService = notificationService ?? NotificationService.instance;

  List<RecurringTransactionModel> _recurringTransactions = [];
  bool _isLoading = false;
  String? _error;

  List<RecurringTransactionModel> get recurringTransactions =>
      _recurringTransactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<RecurringTransactionModel> get activeRecurring =>
      _recurringTransactions.where((r) => r.isActive).toList();

  /// Active templates marked as subscriptions — what the Subscriptions
  /// screen lists, sorted soonest-charge-first.
  List<RecurringTransactionModel> get subscriptions {
    final list = _recurringTransactions.where((r) => r.isActive && r.isSubscription).toList();
    list.sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
    return list;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadRecurringTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recurringTransactions = await _repository.getAll();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a template. Pass [lastRunDate] when the caller has *already*
  /// posted the occurrence for that date — entering an expense and ticking
  /// "recurring" does exactly that. Without it the template's first due date
  /// is [startDate] itself, so a charge that was just paid reads "Due today"
  /// on every surface until the next app launch runs the catch-up pass.
  ///
  /// Left null by the detected-subscription flow, which points [startDate] at
  /// a predicted *future* charge and posts nothing inline.
  Future<RecurringTransactionModel> addRecurring({
    required String type,
    required double amount,
    required String categoryId,
    String? accountId,
    String? merchant,
    String? note,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    DateTime? lastRunDate,
    bool isSubscription = false,
  }) async {
    final recurring = RecurringTransactionModel(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: accountId,
      merchant: merchant,
      note: note,
      frequency: frequency,
      // Both dates are stored date-only, but callers hand us a DateTime.now()
      // that still carries a time. Truncating here keeps the in-memory copy
      // identical to what a reload returns, so day-count labels like
      // "Due in N days" don't shift for the rest of the session.
      startDate: _dateOnly(startDate),
      endDate: endDate == null ? null : _dateOnly(endDate),
      lastRunDate: lastRunDate == null ? null : _dateOnly(lastRunDate),
      isActive: true,
      isSubscription: isSubscription,
      createdAt: DateTime.now(),
    );

    await _repository.insert(recurring);
    _recurringTransactions.insert(0, recurring);
    notifyListeners();
    return recurring;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> updateRecurring(RecurringTransactionModel recurring) async {
    await _repository.update(recurring);
    final index = _recurringTransactions.indexWhere((r) => r.id == recurring.id);
    if (index != -1) {
      _recurringTransactions[index] = recurring;
      notifyListeners();
    }
  }

  Future<void> deleteRecurring(String id) async {
    await _repository.delete(id);
    final index = _recurringTransactions.indexWhere((r) => r.id == id);
    if (index != -1) {
      _recurringTransactions[index] =
          _recurringTransactions[index].copyWith(isActive: false);
    }
    // Unconditional: the row changed in the database whether or not this
    // provider happened to be holding it, and the list has to reflect that.
    notifyListeners();
    await _cancelReminderQuietly(id);
  }

  /// Cancels a reminder without letting a notification-plugin failure
  /// masquerade as a failed database write.
  ///
  /// This used to be an ordinary `await` at the end of [deleteRecurring].
  /// The delete had already committed and the row had already vanished from
  /// the list by then, so a throw from the plugin surfaced to the user as
  /// "Failed to delete" for a delete that plainly worked. A stranded
  /// reminder is not a failed delete — the template is inactive and will
  /// never generate another occurrence, and the reminder is re-derived from
  /// active templates on next launch anyway.
  Future<void> _cancelReminderQuietly(String id) async {
    try {
      await _notificationService.cancelReminder(id);
    } catch (_) {
      // Intentionally swallowed — see above.
    }
  }

  RecurringTransactionModel? _findById(String id) {
    for (final r in _recurringTransactions) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Marks (or unmarks) a template as a subscription — the only thing that
  /// puts it on the Subscriptions screen. Any existing recurring template
  /// can become one; nothing about the template itself changes.
  Future<void> setIsSubscription(String id, bool value) async {
    final current = _findById(id);
    if (current == null) return;
    await updateRecurring(current.copyWith(isSubscription: value));
    if (!value) await _cancelReminderQuietly(id);
  }

  /// Pauses a subscription: it stops generating charges (and its reminder
  /// is cancelled) without touching the template itself, unlike deleting.
  Future<void> pauseSubscription(String id) async {
    final current = _findById(id);
    if (current == null) return;
    await updateRecurring(current.copyWith(isPaused: true));
    await _cancelReminderQuietly(id);
  }

  /// Resumes a paused subscription. `lastRunDate` is bumped to today
  /// rather than left where it was — resuming should feel like restarting
  /// the subscription now, not triggering a burst of catch-up charges for
  /// every period it was paused.
  Future<void> resumeSubscription(String id) async {
    final current = _findById(id);
    if (current == null) return;
    final resumed = current.copyWith(isPaused: false, lastRunDate: DateTime.now());
    await updateRecurring(resumed);
    if (resumed.isSubscription) await _notificationService.scheduleReminder(resumed);
  }

  /// Sets how many days before the next charge to remind the user, or
  /// clears the reminder entirely when [days] is null.
  Future<void> setReminderDaysBefore(String id, int? days) async {
    final current = _findById(id);
    if (current == null) return;
    final updated = current.copyWith(reminderDaysBefore: days, clearReminder: days == null);
    await updateRecurring(updated);
    if (updated.isSubscription) {
      await _notificationService.scheduleReminder(updated);
    }
  }

  Future<void> updateLastRunDate(String id, DateTime date) async {
    await _repository.updateLastRunDate(id, date);
    final index = _recurringTransactions.indexWhere((r) => r.id == id);
    if (index != -1) {
      _recurringTransactions[index] =
          _recurringTransactions[index].copyWith(lastRunDate: date);
    }
  }
}
