import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/core/services/pushlog_api_client.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';
import 'package:pushlog/workout/models/repos/impl/cloud_workout_repository.dart';
import 'package:pushlog/workout/models/repos/impl/local_workout_repository.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockLocalWorkoutRepository extends Mock
    implements LocalWorkoutRepository {}

class _MockPushlogApiClient extends Mock implements PushlogApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(const <String, dynamic>{});
    registerFallbackValue(const WorkoutSnapshot());
  });

  test('seeds a missing D1 snapshot from local training data', () async {
    final auth = _MockFirebaseAuth();
    final user = _MockUser();
    final localRepository = _MockLocalWorkoutRepository();
    final api = _MockPushlogApiClient();
    const localSnapshot = WorkoutSnapshot(
      dayTotals: {'2026-08-06': 24},
    );

    when(() => auth.currentUser).thenReturn(user);
    when(localRepository.loadSnapshot).thenAnswer((_) async => localSnapshot);
    when(
      () => localRepository.saveSnapshot(any()),
    ).thenAnswer((_) async {});
    when(() => api.get('/v1/workout-snapshot')).thenThrow(
      const PushlogApiException(
        statusCode: 404,
        code: 'snapshot_not_found',
        message: 'No workout snapshot exists for this user.',
      ),
    );
    when(
      () => api.put(
        '/v1/workout-snapshot',
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => const {'status': 'stored'});
    final repository = CloudWorkoutRepository(
      localRepository: localRepository,
      auth: auth,
      api: api,
    );

    final result = await repository.loadSnapshot();
    final snapshot = result.getOrElse(
      () => throw TestFailure('Expected training data to load'),
    );

    expect(snapshot.dayTotals, localSnapshot.dayTotals);
    expect(snapshot.lastSyncedAt, isNotNull);
    verify(() => api.get('/v1/workout-snapshot')).called(1);
    verify(
      () => api.put(
        '/v1/workout-snapshot',
        body: any(
          named: 'body',
          that: isA<Map<String, dynamic>>().having(
            (body) => body['snapshot'],
            'snapshot',
            isA<Map<String, dynamic>>(),
          ),
        ),
      ),
    ).called(1);
  });
}
