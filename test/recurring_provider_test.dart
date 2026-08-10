import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/services/notification_service.dart';
import 'package:finta/models/recurring_transaction_model.dart';
import 'package:finta/providers/recurring_provider.dart';
import 'package:finta/repositories/recurring_repository.dart';

/// Stands in for the database. Records what was asked of it so the tests can
/// assert the write happened, and can be told to fail to cover the real
/// failure path.
class _FakeRecurringRepository extends RecurringRepository {
  final List<RecurringTransactionModel> rows;
  bool shouldFailDelete = false;
  final List<String> deleted = [];

  _FakeRecurringRepository(this.rows);

  @override
  Future<List<RecurringTransactionModel>> getAll() async => rows;

  @override
  Future<void> delete(String id) async {
    if (shouldFailDelete) throw Exception('database is gone');
    deleted.add(id);
    final index = rows.indexWhere((r) => r.id == id);
    if (index != -1) rows[index] = rows[index].copyWith(isActive: false);
  }
}

/// A notification service whose `cancelReminder` blows up the way the real
/// plugin can on a device — `MissingPluginException` after a hot restart, a
/// `PlatformException` from a revoked permission.
class _ThrowingNotificationService extends NotificationService {
  int cancelAttempts = 0;

  _ThrowingNotificationService() : super.forTesting();

  @override
  Future<void> cancelReminder(String id) async {
    cancelAttempts++;
    throw Exception('notification plugin unavailable');
  }
}

RecurringTransactionModel template(String id) => RecurringTransactionModel(
      id: id,
      type: 'expense',
      amount: 50000,
      categoryId: 'cat-1',
      frequency: 'monthly',
      startDate: DateTime(2026, 1, 21),
      isActive: true,
      isSubscription: true,
      reminderDaysBefore: 3,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('deleteRecurring', () {
    late _FakeRecurringRepository repository;
    late _ThrowingNotificationService notifications;
    late RecurringProvider provider;

    setUp(() async {
      repository = _FakeRecurringRepository([template('r1'), template('r2')]);
      notifications = _ThrowingNotificationService();
      provider = RecurringProvider(
        repository: repository,
        notificationService: notifications,
      );
      await provider.loadRecurringTransactions();
    });

    // The reported bug: the row was soft-deleted and had already vanished
    // from the list, then `cancelReminder` threw and the screen reported
    // "Failed to delete" for a delete that had plainly worked.
    test('succeeds even when cancelling the reminder throws', () async {
      await expectLater(provider.deleteRecurring('r1'), completes);

      expect(notifications.cancelAttempts, 1, reason: 'the cancel was still attempted');
      expect(repository.deleted, ['r1']);
    });

    test('marks the template inactive despite the reminder failure', () async {
      await provider.deleteRecurring('r1');

      expect(provider.activeRecurring.map((r) => r.id), ['r2']);
      expect(
        provider.recurringTransactions.firstWhere((r) => r.id == 'r1').isActive,
        isFalse,
      );
    });

    test('notifies listeners once the delete has committed', () async {
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.deleteRecurring('r1');

      expect(notified, greaterThan(0));
    });

    // The in-memory list not holding the row is not a reason to stay
    // silent — the database changed either way.
    test('notifies listeners for an id it is not holding', () async {
      var notified = 0;
      provider.addListener(() => notified++);

      await provider.deleteRecurring('not-in-memory');

      expect(notified, greaterThan(0));
    });

    test('still surfaces a genuine database failure', () async {
      repository.shouldFailDelete = true;

      await expectLater(provider.deleteRecurring('r1'), throwsA(isA<Exception>()));
      expect(notifications.cancelAttempts, 0, reason: 'never got past the write');
      expect(provider.activeRecurring.map((r) => r.id), ['r1', 'r2']);
    });
  });
}
