import 'dart:io';
import 'dart:ui' show Locale;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../l10n/app_localizations.dart';
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
/// [init] seeds `tz.local` from the device's own zone via `flutter_timezone`.
/// Without that step the timezone package stays on its UTC default and every
/// "9am" reminder fires at the device's UTC offset instead — 4pm in UTC+7.
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

  /// Language used for reminder text. Set from [SettingsProvider] at startup
  /// and whenever the user switches language, because a service has no
  /// [BuildContext] to resolve [AppLocalizations] from.
  ///
  /// Android caches a notification channel's name at creation, so the channel
  /// label in system settings keeps whichever language was active on first
  /// launch. Only the notification bodies follow a later switch.
  String _languageCode = 'en';

  void setLanguage(String languageCode) => _languageCode = languageCode;

  AppLocalizations get _loc => lookupAppLocalizations(Locale(_languageCode));

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get isSupported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<void> init() async {
    if (!isSupported || _initialized) return;
    tz.initializeTimeZones();
    await _configureLocalTimeZone();

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

  /// Points `tz.local` at the device's zone so a reminder scheduled for 9am
  /// fires at 9am where the user is. Falls back to the UTC default if the
  /// platform hands back a name the tz database does not know, which is
  /// better than failing init and losing reminders altogether.
  Future<void> _configureLocalTimeZone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to resolve local timezone: $e');
    }
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
    final loc = _loc;
    final name = (recurring.merchant?.trim().isNotEmpty ?? false)
        ? recurring.merchant!
        : loc.subscriptionFallbackName;

    await _plugin.zonedSchedule(
      _notificationId(recurring.id),
      loc.subscriptionRenewsSoon(name),
      loc.subscriptionRenewsOn(_formatDate(chargeDate)),
      tz.TZDateTime.from(fireDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(_channelId, loc.notificationChannelName),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
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

  /// A medium-form date, e.g. "12 Sep 2026". The previous raw YYYY-MM-DD read
  /// as a machine timestamp in a user-facing notification.
  ///
  /// Deliberately no locale argument: `initializeDateFormatting` is never
  /// called in this app, so `DateFormat.yMMMd('id')` would throw
  /// `LocaleDataException` — only the built-in en_US symbols are available.
  /// Every other DateFormat here does the same (see AppDateUtils and
  /// backup_restore_screen.dart:67). Localizing dates app-wide is a separate
  /// change: it needs initializeDateFormatting at startup and a sweep of
  /// AppDateUtils.
  String _formatDate(DateTime d) => DateFormat.yMMMd().format(d);
}
