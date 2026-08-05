import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class CompetitionNotificationService {
  CompetitionNotificationService({
    required FirebaseFirestore firestore,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _firestore = firestore,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'pushlog_competition',
    'Friend competition',
    description: 'Lead changes and friend leaderboard updates.',
    importance: Importance.high,
  );

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  String? _uid;
  String? _token;
  bool _initialized = false;

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
    await initialize();

    if (!enabled) {
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

    await _tokenSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen((newToken) async {
      final currentUid = _uid;
      if (currentUid == null) return;
      await _unregisterCurrentToken();
      await _registerToken(currentUid, newToken);
    });
    return true;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
  }

  Future<void> _registerToken(String uid, String token) async {
    _uid = uid;
    _token = token;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('pushTokens')
        .doc(token)
        .set({
          'token': token,
          'platform': _platformName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
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
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('pushTokens')
          .doc(token)
          .delete();
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

    final notificationId =
        (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) &
        0x7fffffff;
    await _localNotifications.show(
      notificationId,
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
