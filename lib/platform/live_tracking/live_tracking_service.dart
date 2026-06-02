import 'package:flutter/services.dart';
import 'package:pushlog/platform/live_tracking/live_tracking_state.dart';

class LiveTrackingService {
  const LiveTrackingService({
    MethodChannel methodChannel = const MethodChannel(channelName),
    EventChannel eventChannel = const EventChannel(eventChannelName),
  }) : _methodChannel = methodChannel,
       _eventChannel = eventChannel;

  static const channelName = 'pushlog/live_tracking';
  static const eventChannelName = 'pushlog/live_tracking/events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<LiveTrackingSnapshot> snapshots() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return LiveTrackingSnapshot.fromMap(
        Map<Object?, Object?>.from(event as Map<Object?, Object?>),
      );
    });
  }

  Future<LiveTrackingSnapshot> status() => _snapshot('status');

  Future<LiveTrackingSnapshot> startPreflight() => _snapshot('startPreflight');

  Future<LiveTrackingSnapshot> beginCountdown() => _snapshot('beginCountdown');

  Future<LiveTrackingSnapshot> togglePause() => _snapshot('togglePause');

  Future<LiveTrackingSnapshot> addManualRep() => _snapshot('addManualRep');

  Future<LiveTrackingSnapshot> finish() => _snapshot('finish');

  Future<void> cancel() async {
    try {
      await _methodChannel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<LiveTrackingSnapshot> _snapshot(String method) async {
    try {
      final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
        method,
      );
      if (result == null) return const LiveTrackingSnapshot.unsupported();
      return LiveTrackingSnapshot.fromMap(result);
    } on MissingPluginException {
      return const LiveTrackingSnapshot.unsupported();
    } on PlatformException {
      return const LiveTrackingSnapshot.unsupported();
    }
  }
}
