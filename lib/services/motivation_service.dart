import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../app.dart';
import '../data/motivation_messages.dart';

/// Schedules the daily motivational reminder notification and rotates
/// through [motivationMessages] without repeats until the bank is exhausted.
///
/// SHIPPED APPROACH: a single OS-level repeating notification, scheduled via
/// `zonedSchedule(..., matchDateTimeComponents: DateTimeComponents.time)`.
/// Android re-arms this alarm itself after every fire, so the notification
/// keeps showing up daily with no app intervention — but the message text is
/// baked in at schedule time and stays the same until [scheduleDaily] runs
/// again. Getting a *different* message every single day would require a
/// background job (WorkManager on Android + BGTaskScheduler on iOS) to
/// reschedule a fresh one-off notification every morning, which this
/// codebase has no infrastructure for yet. As a lightweight middle ground,
/// [refreshIfNeeded] is called on app start: if the previously scheduled
/// fire time has already passed, it reschedules with the next message in
/// the rotation. So the message rotates daily for anyone who opens the app
/// at least once a day; if the app stays closed longer, the same message
/// repeats until the next launch catches it up.
class MotivationService {
  MotivationService._();

  static const channelId = 'daily_motivation';
  static const _channelName = 'Daily motivation';
  static const _channelDescription =
      "Your daily Cadence reminder to check in and practice.";
  static const _notificationId = 1001;

  static const _enabledKey = 'daily_motivation_enabled';
  static const _hourKey = 'daily_motivation_hour';
  static const _minuteKey = 'daily_motivation_minute';
  static const _scheduledAtKey = 'daily_motivation_scheduled_at_ms';
  static const _orderKey = 'daily_motivation_order';
  static const _cursorKey = 'daily_motivation_cursor';

  static const TimeOfDay defaultTime = TimeOfDay(hour: 9, minute: 0);

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Sets up the plugin, the Android notification channel, and the local
  /// timezone. Must run before any scheduling call. Does not request
  /// notification permission — that happens the first time the user
  /// enables daily notifications in Settings.
  static Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(_deviceLocalLocation());

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    // Required whenever the app can run on Windows, even though daily
    // reminders are primarily an Android/iOS feature.
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Cadence',
      appUserModelId: 'Com.Sayit.Cadence',
      guid: 'adf9f042-5100-4c21-ac5f-ff252a49b13e',
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    const channel = AndroidNotificationChannel(
      channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    appRouter?.go('/situations');
  }

  /// True if the app process was cold-started by the user tapping this
  /// notification (as opposed to a normal launch).
  static Future<bool> launchedFromNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  /// Requests notification permission: Android 13+ POST_NOTIFICATIONS, or
  /// iOS alert/badge/sound. Returns whether notifications are permitted.
  ///
  /// Deliberately does NOT request exact-alarm scheduling permission here.
  /// `AndroidFlutterLocalNotificationsPlugin.requestExactAlarmsPermission()`
  /// launches the system "Alarms & reminders" Settings screen via
  /// `startActivityForResult` and the plugin tracks that single in-flight
  /// request in one mutable field (`permissionRequestProgress`) rather than
  /// a queue. If that round trip doesn't cleanly resolve — e.g. the OS
  /// reclaims the backgrounded activity while the user is on that external
  /// screen — the plugin gets stuck thinking a request is still in
  /// progress, and silently fails *every* subsequent permission call
  /// (including plain notification permission) from then on. That's flaky
  /// and not worth it here: `_resolveScheduleMode()` already falls back to
  /// `AndroidScheduleMode.inexactAllowWhileIdle` when exact scheduling
  /// isn't grantable, so the reminder still fires — just without the
  /// precise-to-the-minute guarantee. See daily_reminder_provider.dart's
  /// `setEnabled` for how a failure here now surfaces instead of hanging.
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<TimeOfDay> loadTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_hourKey) ?? defaultTime.hour;
    final minute = prefs.getInt(_minuteKey) ?? defaultTime.minute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Cancels any existing scheduled notification, picks the next unused
  /// message from the rotation, and schedules a repeating daily
  /// notification at [time]. Persists enabled=true and the chosen time.
  static Future<void> scheduleDaily(TimeOfDay time) async {
    await initialize();
    await _plugin.cancel(_notificationId);

    final message = await _nextMessage();
    final scheduledDate = _nextInstanceOfTime(time);
    final scheduleMode = await _resolveScheduleMode();

    await _plugin.zonedSchedule(
      _notificationId,
      'Cadence',
      message,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'open_situations',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);
    await prefs.setInt(
        _scheduledAtKey, scheduledDate.millisecondsSinceEpoch);
  }

  /// Cancels the scheduled reminder and persists enabled=false.
  static Future<void> cancelDaily() async {
    await _plugin.cancel(_notificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_scheduledAtKey);
  }

  /// Call on app start. If daily reminders are on and the last-scheduled
  /// fire time has already passed, reschedules with the next message so
  /// the rotation advances even though the OS reuses the previous payload
  /// on its own repeat. See the class doc for why this exists.
  static Future<void> refreshIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_enabledKey) ?? false)) return;

    final scheduledAtMs = prefs.getInt(_scheduledAtKey);
    if (scheduledAtMs == null) return;
    final scheduledAt = DateTime.fromMillisecondsSinceEpoch(scheduledAtMs);
    if (DateTime.now().isBefore(scheduledAt)) return;

    await scheduleDaily(await loadTime());
  }

  static Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    final canScheduleExact =
        await android.canScheduleExactNotifications() ?? false;
    return canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Picks the next message from a shuffled working order, reshuffling
  /// only once every message in the bank has been used.
  static Future<String> _nextMessage() async {
    final prefs = await SharedPreferences.getInstance();
    var order = prefs
            .getString(_orderKey)
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList() ??
        [];
    var cursor = prefs.getInt(_cursorKey) ?? 0;

    if (order.isEmpty ||
        cursor >= order.length ||
        order.length != motivationMessages.length) {
      order = List.generate(motivationMessages.length, (i) => i)..shuffle();
      cursor = 0;
    }

    final index = order[cursor];
    cursor += 1;

    await prefs.setString(_orderKey, order.join(','));
    await prefs.setInt(_cursorKey, cursor);

    return motivationMessages[index];
  }

  /// Finds a real IANA zone in the bundled `timezone` database whose
  /// *current* UTC offset matches the device's, since this app only
  /// depends on `timezone` (not `flutter_native_timezone`/`flutter_timezone`)
  /// and has no way to ask the OS for its zone name directly.
  ///
  /// A fabricated [tz.Location] (tried first) works fine for the Dart-side
  /// date math in [_nextInstanceOfTime], but `flutter_local_notifications`
  /// *also* sends `location.name` across the platform channel and
  /// re-resolves it natively via `ZoneId.of(name)` on Android — which
  /// throws `Unknown time-zone ID` for a made-up name. The obvious next
  /// choice, `Etc/GMT±N`, doesn't work either: this package's bundled
  /// tzdata excludes the whole `Etc/*` family entirely (verified against
  /// its data file — no fixed-offset zones at all). So instead, search the
  /// loaded database for any real zone currently at the right offset. This
  /// doesn't track DST transitions on its own, but [refreshIfNeeded] is
  /// called on every app launch and re-derives this fresh each time, so a
  /// DST shift self-corrects within a day for anyone who opens the app.
  static tz.Location _deviceLocalLocation() {
    final targetOffset = DateTime.now().timeZoneOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (Duration(milliseconds: location.currentTimeZone.offset) ==
          targetOffset) {
        return location;
      }
    }
    return tz.getLocation('UTC');
  }
}
