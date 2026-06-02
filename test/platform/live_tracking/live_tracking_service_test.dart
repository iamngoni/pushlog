import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/platform/live_tracking/live_tracking_service.dart';
import 'package:pushlog/platform/live_tracking/live_tracking_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(LiveTrackingService.channelName);
  const service = LiveTrackingService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('missing native channel returns unsupported snapshot', () async {
    final status = await service.status();

    expect(status.isSupported, isFalse);
    expect(status.phase, LiveTrackingPhase.unavailable);
    expect(status.canUseAutoTracking, isFalse);
  });

  test('maps native status payload', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'status');
          return <String, Object?>{
            'isSupported': true,
            'cameraAccess': 'ready',
            'phase': 'locked',
            'repCount': 12,
            'manualAdjustments': 1,
            'statusLabel': 'LOCKED',
            'movementLabel': 'UP',
            'metricsLine': 'FACE LOCK CONFIRMED',
            'averageRepDuration': 1.25,
          };
        });

    final status = await service.status();

    expect(status.isSupported, isTrue);
    expect(status.cameraAccess, LiveTrackingCameraAccess.ready);
    expect(status.phase, LiveTrackingPhase.locked);
    expect(status.repCount, 12);
    expect(status.averageRepDuration, const Duration(milliseconds: 1250));
  });

  test('sends start preflight command to native side', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return <String, Object?>{
            'isSupported': true,
            'cameraAccess': 'ready',
            'phase': 'calibrating',
            'repCount': 0,
            'manualAdjustments': 0,
            'statusLabel': 'LOCKING',
            'movementLabel': 'READY',
            'metricsLine': 'HOLD TOP POSITION',
          };
        });

    final status = await service.startPreflight();

    expect(methods, ['startPreflight']);
    expect(status.phase, LiveTrackingPhase.calibrating);
  });
}
