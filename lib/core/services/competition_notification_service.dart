import 'dart:async';
import 'dart:developer';
import 'dart:io';

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

    final remoteMessage =
    await _messaging.getInitialMessage();
    log('Getting initial firebase message ✅');

    if (remoteMessage != null) {
      log('Handling message from clicked notification');
      log('Handling message: $remoteMessage');
    }

    if (Platform.isIOS) {
      await _messaging
          .setForegroundNotificationPresentationOptions(
        alert: true, // Required to display a heads up notification
        badge: true,
        sound: true,
      );
      log('Setting foreground notification presentation options for iOS ✅');
    }


    _initialized = true;
  }

  // print(), not log() — log() goes through the VM service/DevTools logging
  // stream and doesn't reliably show up in a bare `flutter run` terminal.
  // This is the only path that's actually visible while debugging this on
  // a device from the terminal, so keep it as print().
  void _log(String message) =>
      // Deliberate: this is the debug path described above, not leftover.
      // ignore: avoid_print
      print('[CompetitionNotificationService] $message');

  Future<bool> syncForUser({
    required String uid,
    required bool enabled,
    bool requestPermission = false,
  }) async {
    _log('syncForUser called');
    try {
      return await _syncForUser(
        uid: uid,
        enabled: enabled,
        requestFCMPermission: requestPermission,
      );
    } on Exception catch (error, stackTrace) {
      _log('competition notification sync failed $error -> $stackTrace');
      return false;
    }
  }

  Future<bool> _syncForUser({
    required String uid,
    required bool enabled,
    required bool requestFCMPermission,
  }) async {
    _log('wait for initialization');
    await initialize();
    _log('initialized');

    if (!enabled) {
      _log('not enabled, unregistering');
      _notificationPoller?.cancel();
      _notificationPoller = null;
      await _unregisterCurrentToken();
      return false;
    }

    // On iOS, UIApplication.registerForRemoteNotifications() — the call
    // that actually starts the native APNs handshake — only happens as a
    // side effect of requestPermission(), not merely by checking settings.
    // Apple expects it to be called on every launch, not just once ever:
    // gating this behind notDetermined meant it fired for the first grant
    // and then never again, so getAPNSToken()/getToken() kept failing on
    // every subsequent app open with no permission dialog and no error.
    // Calling requestPermission() when already authorized is harmless —
    // iOS answers immediately from the stored decision, no dialog shown.
    var settings = await _messaging.getNotificationSettings();
    if (requestFCMPermission) {
      settings = await _messaging.requestPermission();
    }
    _log('notification settings acquired: ${settings.authorizationStatus}');

    final allowed = switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
      AuthorizationStatus.denied || AuthorizationStatus.notDetermined => false,
    };
    if (!allowed) {
      _log('notification permissions not allowed');
      return false;
    }
    _log('notifications are allowed');

    _uid = uid;

    // On iOS/macOS, getToken() needs the native APNs device token to
    // already be registered with Firebase, and that registration completes
    // asynchronously after permission is granted. Calling getToken() before
    // it lands throws firebase_messaging/apns-token-not-set — this had been
    // failing on every single app open, for every iOS user, silently.
    _log('awaiting APNs token availability');
    if (!await _awaitApnsTokenAvailability()) {
      _log('APNs token never became available, giving up for this sync');
      return false;
    }

    _log('getting messaging token');
    final token = await _messaging.getToken();
    _log('messaging token: $token');
    if (token == null || token.isEmpty) return false;
    await _registerToken(uid, token);
    _log('token registration successful for $uid');
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

  /// Polls for the native APNs device token on iOS/macOS. Android and other
  /// platforms have no such concept and return true immediately. Bounded to
  /// ~3 seconds: APNs registration normally completes near-instantly once
  /// permission is granted, so a longer wait would only mask a genuine
  /// connectivity or provisioning problem instead of failing this sync
  /// attempt cleanly (it retries on every future app open regardless).
  Future<bool> _awaitApnsTokenAvailability() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return true;
    }
    for (var attempt = 0; attempt < 10; attempt++) {
      final token = await _messaging.getAPNSToken();
      if (token != null) { return true;}
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return false;
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
