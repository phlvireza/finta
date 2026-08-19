import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../models/recurring_transaction_model.dart';

/// Schedules local reminders for upcoming subscription charges.
///
/// `flutter_local_notifications` has no Windows implementation (its
/// `zonedSchedule` only supports Android/iOS/macOS — Linux can show
/// immediate notifications but not scheduled ones, and Windows isn't
/// supported at all). Every method here is a safe no-op outside
/// Android/iOS/macOS, which is why this app's Windows dev target can call
/// straight into this service without ever hitting a
/// `MissingPluginException` — reminders simply never fire there.
///
/// Without a device-timezone plugin in this project's dependency list,
/// `tz.local` stays at its UTC default, so a scheduled reminder's actual
/// fire time can be off by the device's UTC offset. Acceptable for a
/// "heads up, this renews soon" nudge; a future pass could tighten this
/// with `flutter_timezone`.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Subclass hook for tests. The production path is the [instance]
  /// singleton; this exists only so a test can stand in a version whose
  /// methods fail on demand, which is how the "reminder failure must not
  /// look like a failed delete" guarantee in [RecurringProvider] is proved.
  @visibleForTesting
  NotificationService.forTesting();

  static const _channelId = 'subscription_reminders';
  static const _channelName = 'Subscription reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get isSupported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<void> init() async {
    if (!isSupported || _initialized) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    await _plugin.initialize(initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// Schedules (or reschedules) [recurring]'s reminder for its current
  /// [RecurringTransactionModel.nextOccurrence], firing at 9am local time
  /// [RecurringTransactionModel.reminderDaysBefore] days ahead of it. A
  /// notification id derived from the template's own id means calling this
  /// again for the same template replaces the previous reminder instead of
  /// stacking duplicates — callers don't need to track whether one was
  /// already scheduled.
  Future<void> scheduleReminder(RecurringTransactionModel recurring) async {
    if (!isSupported) return;

    final days = recurring.reminderDaysBefore;
    if (days == null || recurring.isPaused || !recurring.isActive) {
      await cancelReminder(recurring.id);
      return;
    }

    final chargeDate = recurring.nextOccurrence;
    final fireDate = DateTime(chargeDate.year, chargeDate.month, chargeDate.day - days, 9);
    if (!fireDate.isAfter(DateTime.now())) {
      // Too late for this occurrence's reminder. Nothing to schedule until
      // lastRunDate advances past it on the next recurring-service run,
      // which calls this again for the following charge.
      await cancelReminder(recurring.id);
      return;
    }

    await init();
    final name = (recurring.merchant?.trim().isNotEmpty ?? false) ? recurring.merchant! : 'Subscription';

    await _plugin.zonedSchedule(
      _notificationId(recurring.id),
      '$name renews soon',
      'Renews on ${_formatDate(chargeDate)}',
      tz.TZDateTime.from(fireDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      // Inexact deliberately: SCHEDULE_EXACT_ALARM is a Play-restricted
      // permission granted to alarm and calendar apps, and a "renews soon"
      // reminder does not need that precision. Using the exact mode without
      // the permission throws on Android 14+, where the failure would be
      // swallowed and the reminder would silently never fire.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(String recurringId) async {
    if (!isSupported) return;
    await _plugin.cancel(_notificationId(recurringId));
  }

  /// Notification ids must fit a positive 32-bit int; a template's uuid
  /// string can't be used directly, so this derives a stable one from it.
  int _notificationId(String recurringId) => recurringId.hashCode & 0x7fffffff;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
