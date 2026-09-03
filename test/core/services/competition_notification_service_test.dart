import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/core/services/competition_notification_service.dart';
import 'package:pushlog/core/services/pushlog_api_client.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

class _FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class _FakeNotificationDetails extends Fake implements NotificationDetails {}

class _FakeApi extends Fake implements PushlogApiClient {
  List<Map<String, dynamic>> notifications = [];
  final List<String> acknowledged = [];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async => {'notifications': notifications};

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    acknowledged.addAll(
      List<String>.from(body?['notificationIds'] as List? ?? const []),
    );
    return const {};
  }

  @override
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async => const {};
}

const _authorizedSettings = NotificationSettings(
  alert: AppleNotificationSetting.enabled,
  announcement: AppleNotificationSetting.notSupported,
  authorizationStatus: AuthorizationStatus.authorized,
  badge: AppleNotificationSetting.enabled,
  carPlay: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.enabled,
  notificationCenter: AppleNotificationSetting.enabled,
  showPreviews: AppleShowPreviewSetting.always,
  timeSensitive: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  sound: AppleNotificationSetting.enabled,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
);

const _event = RemoteMessage(
  messageId: 'fcm-message-1',
  data: {'type': 'lead_change', 'notificationId': 'notification-1'},
  notification: RemoteNotification(
    title: 'Leaderboard update: #2',
    body: '@kudapara climbed to #1. 16 reps to move ahead.',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeApi api;
  late FirebaseMessaging messaging;
  late FlutterLocalNotificationsPlugin localNotifications;
  late StreamController<RemoteMessage> foregroundMessages;
  late StreamController<RemoteMessage> openedMessages;

  setUpAll(() {
    registerFallbackValue(_FakeInitializationSettings());
    registerFallbackValue(_FakeNotificationDetails());
  });

  setUp(() {
    api = _FakeApi();
    messaging = _MockFirebaseMessaging();
    localNotifications = _MockLocalNotifications();
    foregroundMessages = StreamController<RemoteMessage>.broadcast();
    openedMessages = StreamController<RemoteMessage>.broadcast();

    when(
      () => localNotifications.initialize(any()),
    ).thenAnswer((_) async => true);
    when(
      () => messaging.getNotificationSettings(),
    ).thenAnswer((_) async => _authorizedSettings);
    when(() => messaging.getToken()).thenAnswer((_) async => 'fcm-token');
    when(() => messaging.getAPNSToken()).thenAnswer((_) async => 'apns-token');
    when(
      () => messaging.onTokenRefresh,
    ).thenAnswer((_) => const Stream<String>.empty());
    when(
      () => messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      ),
    ).thenAnswer((_) async {});
    when(
      () => localNotifications.show(
        any(),
        any(),
        any(),
        any(),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await foregroundMessages.close();
    await openedMessages.close();
  });

  CompetitionNotificationService buildService() =>
      CompetitionNotificationService(
        api: api,
        messaging: messaging,
        localNotifications: localNotifications,
        foregroundMessages: foregroundMessages.stream,
        openedMessages: openedMessages.stream,
      );

  test(
    'cold-opened remote event is not displayed again by the poller',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => messaging.getInitialMessage()).thenAnswer((_) async => _event);
      api.notifications = [
        {
          'notificationId': 'notification-1',
          'title': 'Leaderboard update: #2',
          'body': '@kudapara climbed to #1. 16 reps to move ahead.',
        },
      ];
      final service = buildService();

      expect(
        await service.syncForUser(uid: 'recipient', enabled: true),
        isTrue,
      );

      verifyNever(
        () => localNotifications.show(
          any(),
          any(),
          any(),
          any(),
          payload: any(named: 'payload'),
        ),
      );
      expect(api.acknowledged, isNotEmpty);
      expect(api.acknowledged, everyElement('notification-1'));
      await service.dispose();
    },
  );

  test(
    'iOS foreground event relies on native presentation and is acknowledged',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);
      final service = buildService();
      await service.syncForUser(uid: 'recipient', enabled: true);

      foregroundMessages.add(_event);
      await pumpEventQueue();

      verifyNever(
        () => localNotifications.show(
          any(),
          any(),
          any(),
          any(),
          payload: any(named: 'payload'),
        ),
      );
      expect(api.acknowledged, ['notification-1']);
      await service.dispose();
    },
  );

  test('macOS foreground event still uses local presentation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);
    final service = buildService();
    await service.syncForUser(uid: 'recipient', enabled: true);

    foregroundMessages.add(_event);
    await pumpEventQueue();

    verify(
      () => localNotifications.show(
        'notification-1'.hashCode & 0x7fffffff,
        'Leaderboard update: #2',
        '@kudapara climbed to #1. 16 reps to move ahead.',
        any(),
        payload: 'notification-1',
      ),
    ).called(1);
    expect(api.acknowledged, ['notification-1']);
    await service.dispose();
  });

  test('repeated Android foreground event is displayed only once', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    when(() => messaging.getInitialMessage()).thenAnswer((_) async => null);
    final service = buildService();
    await service.syncForUser(uid: 'recipient', enabled: true);

    foregroundMessages
      ..add(_event)
      ..add(_event);
    await pumpEventQueue();

    verify(
      () => localNotifications.show(
        'notification-1'.hashCode & 0x7fffffff,
        'Leaderboard update: #2',
        '@kudapara climbed to #1. 16 reps to move ahead.',
        any(),
        payload: 'notification-1',
      ),
    ).called(1);
    expect(api.acknowledged, ['notification-1']);
    await service.dispose();
  });
}
