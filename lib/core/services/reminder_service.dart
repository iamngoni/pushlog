import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pushlog/training/models/training_plan.dart';
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
    'Pushlog Training Reminders',
    description: 'Reminders for planned Pushlog training days.',
    importance: Importance.high,
  );

  static const _notificationBaseId = 7100;
  static const _notificationWindowDays = 21;

  static const List<({String title, String body})> _fallbackCopies = [
    (
      title: 'Training when you are ready.',
      body: 'Your Pushlog session is ready to open.',
    ),
    (
      title: 'A small session still counts.',
      body: 'Log clean reps and adjust the effort to today.',
    ),
    (
      title: 'Pushlog reminder.',
      body: 'Your next clean set can start here.',
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

    final scheduledDates = scheduledDatesFor(
      preferences,
      now: DateTime.now(),
    );
    for (var index = 0; index < scheduledDates.length; index++) {
      final scheduledAt = scheduledDates[index];
      final copy = copyFor(preferences, scheduledAt);

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

  List<DateTime> scheduledDatesFor(
    WorkoutPreferences preferences, {
    required DateTime now,
    int windowDays = _notificationWindowDays,
  }) {
    final plan = preferences.trainingPlan;
    final dates = <DateTime>[];
    for (var offset = 0; offset < windowDays; offset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day + offset,
        preferences.reminderHour,
        preferences.reminderMinute,
      );
      if (!date.isAfter(now.add(const Duration(seconds: 5)))) continue;
      if (plan != null && !plan.isTrainingDay(date)) continue;
      dates.add(date);
    }
    return dates;
  }

  ({String title, String body}) copyFor(
    WorkoutPreferences preferences,
    DateTime scheduledAt,
  ) {
    final plan = preferences.trainingPlan;
    if (plan != null) {
      final session = plan.sessionFor(scheduledAt);
      final prescription = '${session.sets} × ${session.repsPerSet} clean reps';
      if (!preferences.smartReminderCopyEnabled) {
        return (
          title: 'Pushlog training day',
          body: "Today's plan: $prescription.",
        );
      }
      return switch (plan.profile.coachingStyle) {
        CoachingStyle.calm => (
          title: "Today's session is ready.",
          body: '$prescription. Adjust if you need to.',
        ),
        CoachingStyle.energetic => (
          title: 'Training day.',
          body: '$prescription. Start when you are ready.',
        ),
        CoachingStyle.minimal => (
          title: 'Pushlog',
          body: '$prescription today.',
        ),
      };
    }

    if (!preferences.smartReminderCopyEnabled) {
      return (
        title: 'Pushlog reminder',
        body: 'Your Pushlog session is ready.',
      );
    }

    final seed = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
    ).millisecondsSinceEpoch;
    return _fallbackCopies[seed % _fallbackCopies.length];
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
