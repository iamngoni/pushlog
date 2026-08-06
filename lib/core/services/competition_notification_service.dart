import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pushlog/core/services/pushlog_api_client.dart';

class CompetitionNotificationService {
  CompetitionNotificationService({
    required PushlogApiClient api,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _api = api,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'pushlog_competition',
    'Friend competition',
    description: 'Lead changes and friend leaderboard updates.',
    importance: Importance.high,
  );

  final PushlogApiClient _api;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  Timer? _notificationPoller;
  String? _uid;
  String? _token;
  bool _initialized = false;
  bool _polling = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundMessage,
    );
    _initialized = true;
  }

  Future<bool> syncForUser({
    required String uid,
    required bool enabled,
    bool requestPermission = false,
  }) async {
    try {
      return await _syncForUser(
        uid: uid,
        enabled: enabled,
        requestPermission: requestPermission,
      );
    } on Exception catch (error, stackTrace) {
      log(
        'competition notification sync failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> _syncForUser({
    required String uid,
    required bool enabled,
    required bool requestPermission,
  }) async {
    await initialize();

    if (!enabled) {
      _notificationPoller?.cancel();
      _notificationPoller = null;
      await _unregisterCurrentToken();
      return false;
    }

    var settings = await _messaging.getNotificationSettings();
    if (requestPermission &&
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      settings = await _messaging.requestPermission();
    }

    final allowed = switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
      AuthorizationStatus.denied || AuthorizationStatus.notDetermined => false,
    };
    if (!allowed) return false;

    _uid = uid;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return false;
    await _registerToken(uid, token);
    await _pollNotifications();
    _notificationPoller?.cancel();
    _notificationPoller = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_pollNotifications()),
    );

    await _tokenSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
      final currentUid = _uid;
      if (currentUid == null) return;
      try {
        await _unregisterCurrentToken();
        await _registerToken(currentUid, newToken);
      } on Exception catch (error, stackTrace) {
        log(
          'competition notification token refresh failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    return true;
  }

  Future<void> dispose() async {
    _notificationPoller?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
  }

  Future<void> _registerToken(String uid, String token) async {
    _uid = uid;
    _token = token;
    await _api.put(
      '/v1/devices',
      body: {'token': token, 'platform': _platformName},
    );
  }

  Future<void> _unregisterCurrentToken() async {
    final uid = _uid;
    final token = _token;
    _uid = null;
    _token = null;
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    if (uid == null || token == null) return;

    try {
      await _api.delete('/v1/devices', body: {'token': token});
    } on Exception catch (error, stackTrace) {
      log(
        'competition token removal failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || message.data['type'] != 'lead_change') return;

    final displayId =
        (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) &
        0x7fffffff;
    await _localNotifications.show(
      displayId,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pushlog_competition',
          'Friend competition',
          channelDescription: 'Lead changes and friend leaderboard updates.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: message.data['notificationId'] as String?,
    );
    final eventId = message.data['notificationId'];
    if (eventId is String && eventId.isNotEmpty) {
      await _markRead([eventId]);
    }
  }

  Future<void> _pollNotifications() async {
    if (_uid == null || _polling) return;
    _polling = true;
    try {
      final response = await _api.get(
        '/v1/notifications',
        query: const {'limit': '25'},
      );
      final rawNotifications = response['notifications'];
      if (rawNotifications is! List) return;

      final displayed = <String>[];
      for (final raw in rawNotifications) {
        if (raw is! Map) continue;
        final notification = Map<String, dynamic>.from(raw);
        final notificationId = notification['notificationId'];
        final title = notification['title'];
        final body = notification['body'];
        if (notificationId is! String ||
            notificationId.isEmpty ||
            title is! String ||
            body is! String) {
          continue;
        }
        await _localNotifications.show(
          notificationId.hashCode & 0x7fffffff,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'pushlog_competition',
              'Friend competition',
              channelDescription:
                  'Lead changes and friend leaderboard updates.',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          payload: notificationId,
        );
        displayed.add(notificationId);
      }
      if (displayed.isNotEmpty) await _markRead(displayed);
    } on Exception catch (error, stackTrace) {
      log(
        'competition notification poll failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _polling = false;
    }
  }

  Future<void> _markRead(List<String> notificationIds) async {
    try {
      await _api.post(
        '/v1/notifications',
        body: {'notificationIds': notificationIds},
      );
    } on Exception catch (error, stackTrace) {
      log(
        'competition notification acknowledgement failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String get _platformName => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.fuchsia => 'fuchsia',
    TargetPlatform.linux => 'linux',
    TargetPlatform.windows => 'windows',
  };
}
