import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  ReminderService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channel = AndroidNotificationChannel(
    'pushlog_daily_reminders',
    'Pushlog Daily Reminders',
    description: 'Daily reminders to log your pushups.',
    importance: Importance.high,
  );

  static const _notificationBaseId = 7100;
  static const _notificationWindowDays = 21;

  static const List<({String title, String body})> _smartCopies = [
    (
      title: 'Pushlog wants a set.',
      body: 'Do not let today finish at zero.',
    ),
    (
      title: 'Clock is running.',
      body: 'Log a set now and keep the board moving.',
    ),
    (
      title: 'Friends board check.',
      body: 'Somebody can catch you if you stay still.',
    ),
    (
      title: 'Quick session.',
      body: '+10 is enough to change the day.',
    ),
    (
      title: 'Stay dangerous.',
      body: 'Drop and give yourself a better streak.',
    ),
    (
      title: 'Pushlog reminder.',
      body: 'One set today is better than none.',
    ),
    (
      title: 'Board pressure.',
      body: 'Your username looks better with fresh reps on it.',
    ),
    (
      title: 'No dead days.',
      body: 'Open Pushlog and get a set in.',
    ),
  ];

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );

    await _configureLocalTimeZone();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();

    var granted = true;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      granted =
          (await android.requestNotificationsPermission() ?? true) && granted;
    }
    if (ios != null) {
      granted =
          (await ios.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              true) &&
          granted;
    }
    if (macos != null) {
      granted =
          (await macos.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
              true) &&
          granted;
    }

    return granted;
  }

  Future<void> syncPreferences(
    WorkoutPreferences preferences,
  ) async {
    await initialize();
    await cancelAllManaged();

    if (!preferences.remindersEnabled) return;

    final granted = await requestPermissions();
    if (!granted) {
      log('reminder permission not granted');
      return;
    }

    for (var index = 0; index < _notificationWindowDays; index++) {
      final scheduledAt = _scheduledDate(
        preferences: preferences,
        dayOffset: index,
      );
      final copy = _copyFor(
        scheduledAt,
        smart: preferences.smartReminderCopyEnabled,
      );

      await _plugin.zonedSchedule(
        _notificationBaseId + index,
        copy.title,
        copy.body,
        tz.TZDateTime.from(scheduledAt, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAllManaged() async {
    await initialize();
    for (var index = 0; index < _notificationWindowDays; index++) {
      await _plugin.cancel(_notificationBaseId + index);
    }
  }

  DateTime _scheduledDate({
    required WorkoutPreferences preferences,
    required int dayOffset,
  }) {
    final now = DateTime.now();
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      preferences.reminderHour,
      preferences.reminderMinute,
    ).add(Duration(days: dayOffset));

    if (dayOffset == 0 &&
        !candidate.isAfter(now.add(const Duration(seconds: 5)))) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return candidate;
  }

  ({String title, String body}) _copyFor(
    DateTime scheduledAt, {
    required bool smart,
  }) {
    if (!smart) {
      return (
        title: 'Pushlog reminder',
        body: "Time to log today's pushups.",
      );
    }

    final seed = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
    ).millisecondsSinceEpoch;
    return _smartCopies[seed % _smartCopies.length];
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();

    if (kIsWeb ||
        (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS)) {
      return;
    }

    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } on Exception catch (error, stackTrace) {
      log(
        'timezone configuration failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
