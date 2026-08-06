import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/core/services/workout_shadow_sync_service.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _RecordingTransport {
  _RecordingTransport({this.status = HttpStatus.accepted});

  final int status;
  Uri? uri;
  Map<String, String>? headers;
  String? body;
  int callCount = 0;

  Future<int> put({
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    callCount += 1;
    this.uri = uri;
    this.headers = headers;
    this.body = body;
    return status;
  }
}

void main() {
  group(CloudflareWorkoutShadowSyncService, () {
    late _MockFirebaseAuth auth;

    setUp(() {
      auth = _MockFirebaseAuth();
    });

    test('does nothing when no build-time endpoint is configured', () async {
      final transport = _RecordingTransport();
      final service = CloudflareWorkoutShadowSyncService(
        auth: auth,
        transport: transport.put,
      );

      await service.syncWorkoutSnapshot(const WorkoutSnapshot());

      expect(service.isEnabled, isFalse);
      expect(transport.callCount, isZero);
      verifyNever(() => auth.currentUser);
    });

    test('sends the snapshot with a Firebase ID token', () async {
      final user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(user.getIdToken).thenAnswer((_) async => 'firebase-token');
      final transport = _RecordingTransport();
      final service = CloudflareWorkoutShadowSyncService(
        auth: auth,
        baseUrl: 'https://pushlog-api-staging.example.workers.dev',
        transport: transport.put,
      );
      final snapshot = WorkoutSnapshot(
        dayTotals: const {'2026-08-06': 12},
        updatedAt: DateTime.utc(2026, 8, 6),
      );

      await service.syncWorkoutSnapshot(snapshot);

      expect(service.isEnabled, isTrue);
      expect(
        transport.uri,
        Uri.parse(
          'https://pushlog-api-staging.example.workers.dev/'
          'v1/workout-snapshot',
        ),
      );
      expect(
        transport.headers?[HttpHeaders.authorizationHeader],
        'Bearer firebase-token',
      );
      expect(
        jsonDecode(transport.body!) as Map<String, dynamic>,
        {'snapshot': snapshot.toJson()},
      );
    });

    test(
      'surfaces a non-success response to the repository boundary',
      () async {
        final user = _MockUser();
        when(() => auth.currentUser).thenReturn(user);
        when(user.getIdToken).thenAnswer((_) async => 'firebase-token');
        final service = CloudflareWorkoutShadowSyncService(
          auth: auth,
          baseUrl: 'https://pushlog-api-staging.example.workers.dev',
          transport: _RecordingTransport(
            status: HttpStatus.unauthorized,
          ).put,
        );

        await expectLater(
          service.syncWorkoutSnapshot(const WorkoutSnapshot()),
          throwsA(isA<HttpException>()),
        );
      },
    );
  });
}
