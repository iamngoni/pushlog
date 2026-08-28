import 'package:flutter/services.dart';

enum HealthAuthorizationStatus {
  unavailable,
  notDetermined,
  authorized,
  denied,
}

class HealthService {
  const HealthService({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const channelName = 'pushlog/health';

  final MethodChannel _channel;

  Future<HealthAuthorizationStatus> authorizationStatus() async {
    try {
      final status = await _channel.invokeMethod<String>(
        'authorizationStatus',
      );
      return _statusFromNative(status);
    } on MissingPluginException {
      return HealthAuthorizationStatus.unavailable;
    } on PlatformException {
      return HealthAuthorizationStatus.unavailable;
    }
  }

  Future<bool> requestAuthorization() async {
    try {
      return await _channel.invokeMethod<bool>(
            'requestAuthorization',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> saveLiveSession({
    required int reps,
    required Duration duration,
    required int manualAdjustments,
    required DateTime endedAt,
    required String externalId,
  }) async {
    if (reps <= 0) return false;

    try {
      return await _channel.invokeMethod<bool>(
            'saveLiveSession',
            {
              'reps': reps,
              'durationMicroseconds': duration.inMicroseconds,
              'manualAdjustments': manualAdjustments,
              // Epoch milliseconds cross the platform channel without any
              // locale, time-zone, or fractional-second parsing ambiguity.
              'endedAtEpochMilliseconds': endedAt.millisecondsSinceEpoch,
              'externalId': externalId,
            },
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  HealthAuthorizationStatus _statusFromNative(String? value) {
    return switch (value) {
      'authorized' => HealthAuthorizationStatus.authorized,
      'denied' => HealthAuthorizationStatus.denied,
      'notDetermined' => HealthAuthorizationStatus.notDetermined,
      _ => HealthAuthorizationStatus.unavailable,
    };
  }
}
