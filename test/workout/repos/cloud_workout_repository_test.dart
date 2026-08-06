// Firestore's sealed API types require mock implementations for this repository
// boundary test.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';
import 'package:pushlog/workout/models/repos/impl/cloud_workout_repository.dart';
import 'package:pushlog/workout/models/repos/impl/local_workout_repository.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _MockLocalWorkoutRepository extends Mock
    implements LocalWorkoutRepository {}

class _MockProfileService extends Mock implements ProfileService {}

void main() {
  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
    registerFallbackValue(const WorkoutSnapshot());
  });

  test(
    'loads private training data when public stats sync is denied',
    () async {
      final auth = _MockFirebaseAuth();
      final user = _MockUser();
      final firestore = _MockFirebaseFirestore();
      final users = _MockCollectionReference();
      final userDocument = _MockDocumentReference();
      final privateState = _MockCollectionReference();
      final workoutDocument = _MockDocumentReference();
      final remoteDocument = _MockDocumentSnapshot();
      final localRepository = _MockLocalWorkoutRepository();
      final profileService = _MockProfileService();
      var shadowSyncCalls = 0;
      Future<void> failingShadowSync(WorkoutSnapshot snapshot) async {
        shadowSyncCalls += 1;
        throw Exception('D1 is unavailable');
      }

      const localSnapshot = WorkoutSnapshot(
        dayTotals: {'2026-08-06': 24},
      );

      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('user-1');
      when(localRepository.loadSnapshot).thenAnswer((_) async => localSnapshot);
      when(
        () => localRepository.saveSnapshot(any()),
      ).thenAnswer((_) async {});
      when(
        () => profileService.ensureProfileShell(user),
      ).thenAnswer((_) async {});
      when(() => firestore.collection('users')).thenReturn(users);
      when(() => users.doc('user-1')).thenReturn(userDocument);
      when(
        () => userDocument.collection('privateState'),
      ).thenReturn(privateState);
      when(() => privateState.doc('workout')).thenReturn(workoutDocument);
      when(workoutDocument.get).thenAnswer((_) async => remoteDocument);
      when(() => remoteDocument.exists).thenReturn(false);
      when(
        () => workoutDocument.set(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => profileService.updateStatsFromSnapshot(
          user: user,
          snapshot: any(named: 'snapshot'),
        ),
      ).thenThrow(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );
      final repository = CloudWorkoutRepository(
        localRepository: localRepository,
        auth: auth,
        firestore: firestore,
        profileService: profileService,
        shadowSync: failingShadowSync,
      );

      final result = await repository.loadSnapshot();
      await Future<void>.delayed(Duration.zero);
      final snapshot = result.getOrElse(
        () => throw TestFailure('Expected training data to load'),
      );

      expect(snapshot.dayTotals, localSnapshot.dayTotals);
      expect(snapshot.lastSyncedAt, isNotNull);
      verify(
        () => workoutDocument.set(any(), any()),
      ).called(1);
      verify(
        () => profileService.updateStatsFromSnapshot(
          user: user,
          snapshot: any(named: 'snapshot'),
        ),
      ).called(1);
      expect(shadowSyncCalls, 1);
    },
  );
}
