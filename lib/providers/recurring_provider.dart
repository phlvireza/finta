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
    bool isSubscription = false,
  }) async {
    try {
      final recurring = RecurringTransactionModel(
        id: _uuid.v4(),
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        merchant: merchant,
        note: note,
        frequency: frequency,
        startDate: startDate,
        endDate: endDate,
        isActive: true,
        isSubscription: isSubscription,
        createdAt: DateTime.now(),
      );

      await _repository.insert(recurring);
      _recurringTransactions.insert(0, recurring);
      notifyListeners();
      return recurring;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateRecurring(RecurringTransactionModel recurring) async {
    try {
      await _repository.update(recurring);
      final index = _recurringTransactions.indexWhere((r) => r.id == recurring.id);
      if (index != -1) {
        _recurringTransactions[index] = recurring;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteRecurring(String id) async {
    try {
      await _repository.delete(id);
      final index = _recurringTransactions.indexWhere((r) => r.id == id);
      if (index != -1) {
        _recurringTransactions[index] =
            _recurringTransactions[index].copyWith(isActive: false);
        notifyListeners();
      }
      await _notificationService.cancelReminder(id);
    } catch (e) {
      rethrow;
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
    if (!value) await _notificationService.cancelReminder(id);
  }

  /// Pauses a subscription: it stops generating charges (and its reminder
  /// is cancelled) without touching the template itself, unlike deleting.
  Future<void> pauseSubscription(String id) async {
    final current = _findById(id);
    if (current == null) return;
    await updateRecurring(current.copyWith(isPaused: true));
    await _notificationService.cancelReminder(id);
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
    try {
      await _repository.updateLastRunDate(id, date);
      final index = _recurringTransactions.indexWhere((r) => r.id == id);
      if (index != -1) {
        _recurringTransactions[index] =
            _recurringTransactions[index].copyWith(lastRunDate: date);
      }
    } catch (e) {
      rethrow;
    }
  }
}
