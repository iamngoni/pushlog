import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/platform/health/health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(HealthService.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('returns unavailable when the platform channel is missing', () async {
    const service = HealthService();

    final status = await service.authorizationStatus();
    final requested = await service.requestAuthorization();

    expect(status, HealthAuthorizationStatus.unavailable);
    expect(requested, isFalse);
  });

  test('maps native authorization status labels', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'authorizationStatus');
      return 'authorized';
    });
    const service = HealthService();

    final status = await service.authorizationStatus();

    expect(status, HealthAuthorizationStatus.authorized);
  });

  test('sends live session payload to the native health bridge', () async {
    final endedAt = DateTime(2026, 5, 30, 12, 30);
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    const service = HealthService();

    final saved = await service.saveLiveSession(
      reps: 42,
      duration: const Duration(minutes: 3, seconds: 20),
      manualAdjustments: 2,
      endedAt: endedAt,
      externalId: 'session-42',
      effortScore: 7,
    );

    expect(saved, isTrue);
    expect(calls.single.method, 'saveLiveSession');
    expect(calls.single.arguments, {
      'reps': 42,
      'durationMicroseconds': 200000000,
      'manualAdjustments': 2,
      'endedAtEpochMilliseconds': endedAt.millisecondsSinceEpoch,
      'externalId': 'session-42',
      'effortScore': 7,
    });
  });
}
