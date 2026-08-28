import 'package:flutter/services.dart';
import 'package:pushlog/platform/watch/watch_state.dart';

class WatchService {
  const WatchService({
    MethodChannel methodChannel = const MethodChannel(channelName),
    EventChannel eventChannel = const EventChannel(eventChannelName),
  }) : _methodChannel = methodChannel,
       _eventChannel = eventChannel;

  static const channelName = 'pushlog/watch';
  static const eventChannelName = 'pushlog/watch/events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<WatchStatus> statuses() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return WatchStatus.fromMap(
        Map<Object?, Object?>.from(event as Map<Object?, Object?>),
      );
    });
  }

  Future<WatchStatus> status() => _status('status');

  Future<WatchStatus> beginLiveWorkout({
    required String sessionId,
    required DateTime startedAt,
    required bool preferWatch,
  }) async {
    return _status(
      'beginLiveWorkout',
      <String, Object?>{
        'sessionId': sessionId,
        'startedAt': startedAt.toIso8601String(),
        'startedAtMillisecondsSinceEpoch': startedAt.millisecondsSinceEpoch,
        'preferWatch': preferWatch,
      },
    );
  }

  Future<void> sendLiveUpdate({
    required String sessionId,
    required int reps,
    required Duration elapsed,
    required String phase,
    required String trackingState,
    required bool isPaused,
  }) async {
    await _invoke(
      'sendLiveUpdate',
      <String, Object?>{
        'sessionId': sessionId,
        'reps': reps,
        'elapsedSeconds': elapsed.inMilliseconds / 1000,
        'phase': phase,
        'trackingState': trackingState,
        'isPaused': isPaused,
      },
    );
  }

  Future<HealthKitWriteOwner> stopLiveWorkout({
    required String sessionId,
    required int reps,
    required Duration duration,
    required DateTime endedAt,
  }) async {
    try {
      final owner = await _methodChannel.invokeMethod<String>(
        'stopLiveWorkout',
        <String, Object?>{
          'sessionId': sessionId,
          'reps': reps,
          'durationSeconds': duration.inMilliseconds / 1000,
          'endedAt': endedAt.toIso8601String(),
          'endedAtMillisecondsSinceEpoch': endedAt.millisecondsSinceEpoch,
        },
      );
      return owner == 'watch'
          ? HealthKitWriteOwner.watch
          : HealthKitWriteOwner.phone;
    } on MissingPluginException {
      return HealthKitWriteOwner.phone;
    } on PlatformException {
      return HealthKitWriteOwner.phone;
    }
  }

  Future<HealthKitWriteOwner> commitStoppedWorkout({
    required String sessionId,
    int? effortScore,
  }) async {
    try {
      final owner = await _methodChannel.invokeMethod<String>(
        'commitStoppedWorkout',
        <String, Object?>{
          'sessionId': sessionId,
          'effortScore': effortScore,
        },
      );
      return owner == 'watch'
          ? HealthKitWriteOwner.watch
          : HealthKitWriteOwner.phone;
    } on MissingPluginException {
      return HealthKitWriteOwner.phone;
    } on PlatformException {
      return HealthKitWriteOwner.phone;
    }
  }

  Future<void> discardStoppedWorkout({required String sessionId}) async {
    await _invoke('discardStoppedWorkout', <String, Object?>{
      'sessionId': sessionId,
    });
  }

  Future<void> cancelLiveWorkout({required String sessionId}) async {
    await _invoke('cancelLiveWorkout', <String, Object?>{
      'sessionId': sessionId,
    });
  }

  Future<WatchStatus> _status(String method, [Object? arguments]) async {
    try {
      final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
        method,
        arguments,
      );
      if (result == null) return const WatchStatus.unsupported();
      return WatchStatus.fromMap(result);
    } on MissingPluginException {
      return const WatchStatus.unsupported();
    } on PlatformException {
      return const WatchStatus.unsupported();
    }
  }

  Future<void> _invoke(String method, Object? arguments) async {
    try {
      await _methodChannel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}
