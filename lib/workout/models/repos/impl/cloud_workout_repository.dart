import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/core/models/data/application_error.dart';
import 'package:pushlog/core/services/workout_shadow_sync_service.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';
import 'package:pushlog/workout/models/repos/abs/workout_repository.dart';
import 'package:pushlog/workout/models/repos/impl/local_workout_repository.dart';

class CloudWorkoutRepository implements WorkoutRepository {
  CloudWorkoutRepository({
    required this.localRepository,
    required this.auth,
    required this.firestore,
    required this.profileService,
    this.shadowSync = noopWorkoutShadowSync,
  });

  final LocalWorkoutRepository localRepository;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final ProfileService profileService;
  final WorkoutShadowSync shadowSync;

  WorkoutSnapshot? _memorySnapshot;

  DocumentReference<Map<String, dynamic>> _stateDocument(String uid) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('privateState')
        .doc('workout');
  }

  @override
  Future<Either<ApplicationError, WorkoutSnapshot>> loadSnapshot() async {
    try {
      final localSnapshot = (await localRepository.loadSnapshot()).normalized();
      final user = auth.currentUser;
      if (user == null) {
        _memorySnapshot = localSnapshot;
        return Right(localSnapshot);
      }

      await profileService.ensureProfileShell(user);

      final remoteDocument = await _stateDocument(user.uid).get();
      if (!remoteDocument.exists || remoteDocument.data() == null) {
        if (!localSnapshot.isEmpty) {
          final seeded = await _pushRemote(user, localSnapshot);
          _memorySnapshot = seeded;
          return Right(seeded);
        }

        _memorySnapshot = localSnapshot;
        return Right(localSnapshot);
      }

      final remoteSnapshot = WorkoutSnapshot.fromJson(
        remoteDocument.data()!,
      );

      final chosen = localSnapshot.isEmpty
          ? remoteSnapshot.copyWith(
              lastSyncedAt: remoteSnapshot.lastSyncedAt ?? DateTime.now(),
            )
          : await _pushRemote(
              user,
              localSnapshot.mergeWith(remoteSnapshot),
            );

      await localRepository.saveSnapshot(chosen);
      _memorySnapshot = chosen;
      return Right(chosen);
    } on Exception catch (error, stackTrace) {
      log(
        'workout snapshot load error',
        error: error,
        stackTrace: stackTrace,
      );
      return Left(ApplicationError.storageError(error.toString()));
    }
  }

  @override
  Future<Either<ApplicationError, WorkoutSnapshot>> saveSnapshot(
    WorkoutSnapshot snapshot,
  ) async {
    try {
      final normalized = snapshot.normalized().copyWith(
        updatedAt: DateTime.now(),
      );
      await localRepository.saveSnapshot(normalized);

      final user = auth.currentUser;
      if (user == null) {
        _memorySnapshot = normalized;
        return Right(normalized);
      }

      final synced = await _pushRemote(user, normalized);
      _memorySnapshot = synced;
      return Right(synced);
    } on Exception catch (error, stackTrace) {
      log(
        'workout snapshot save error',
        error: error,
        stackTrace: stackTrace,
      );
      return Left(ApplicationError.storageError(error.toString()));
    }
  }

  @override
  Future<Either<ApplicationError, WorkoutSnapshot>> resetSnapshot() async {
    const empty = WorkoutSnapshot();
    await localRepository.resetScopedData();
    return saveSnapshot(empty);
  }

  @override
  Future<Either<ApplicationError, String>> exportJson() async {
    try {
      final snapshot =
          _memorySnapshot ??
          (await loadSnapshot()).getOrElse(
            () => const WorkoutSnapshot(),
          );
      return Right(
        const JsonEncoder.withIndent('  ').convert(
          snapshot.toJson(),
        ),
      );
    } on Exception catch (error, stackTrace) {
      log(
        'workout export error',
        error: error,
        stackTrace: stackTrace,
      );
      return Left(ApplicationError.storageError(error.toString()));
    }
  }

  Future<WorkoutSnapshot> _pushRemote(
    User user,
    WorkoutSnapshot snapshot,
  ) async {
    final syncedAt = DateTime.now();
    final remoteSnapshot = snapshot.copyWith(
      lastSyncedAt: syncedAt,
    );

    await _stateDocument(user.uid).set(
      remoteSnapshot.toJson(),
      SetOptions(merge: true),
    );
    await localRepository.saveSnapshot(remoteSnapshot);
    try {
      await profileService.updateStatsFromSnapshot(
        user: user,
        snapshot: remoteSnapshot,
      );
    } on Exception catch (error, stackTrace) {
      log(
        'public workout stats sync failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    unawaited(_syncShadow(remoteSnapshot));
    return remoteSnapshot;
  }

  Future<void> _syncShadow(WorkoutSnapshot snapshot) async {
    try {
      await shadowSync(snapshot);
    } on Exception catch (error, stackTrace) {
      log(
        'workout shadow sync failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
