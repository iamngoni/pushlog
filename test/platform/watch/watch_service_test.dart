import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/platform/watch/watch_service.dart';
import 'package:pushlog/platform/watch/watch_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WatchService.channelName);
  const service = WatchService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('missing native channel reports iPhone-only status', () async {
    final status = await service.status();

    expect(status.isSupported, isFalse);
    expect(status.canUseForWorkout, isFalse);
    expect(status.statusLabel, 'IPHONE ONLY');
  });

  test('maps watch availability payload', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'status');
          return <String, Object?>{
            'isSupported': true,
            'isPaired': true,
            'isAppInstalled': true,
            'isReachable': false,
            'statusLabel': 'WATCH READY',
            'currentHeartRate': 88.5,
          };
        });

    final status = await service.status();

    expect(status.canUseForWorkout, isTrue);
    expect(status.statusLabel, 'WATCH READY');
    expect(status.currentHeartRate, 88.5);
  });

  test('sends live workout start payload', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return <String, Object?>{
            'isSupported': true,
            'isPaired': true,
            'isAppInstalled': true,
            'isReachable': true,
            'statusLabel': 'WATCH REQUESTED',
          };
        });

    final startedAt = DateTime.utc(2026);
    final status = await service.beginLiveWorkout(
      sessionId: 'session-1',
      startedAt: startedAt,
      preferWatch: true,
    );

    expect(status.statusLabel, 'WATCH REQUESTED');
    expect(calls.single.method, 'beginLiveWorkout');
    expect(calls.single.arguments, {
      'sessionId': 'session-1',
      'startedAt': startedAt.toIso8601String(),
      'startedAtMillisecondsSinceEpoch': startedAt.millisecondsSinceEpoch,
      'preferWatch': true,
    });
  });

  test('maps stop owner to watch', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 'watch');

    final owner = await service.stopLiveWorkout(
      sessionId: 'session-1',
      reps: 10,
      duration: const Duration(minutes: 1),
      endedAt: DateTime.utc(2026),
    );

    expect(owner, HealthKitWriteOwner.watch);
  });
}
