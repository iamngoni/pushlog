import 'dart:convert';
import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pushlog/core/models/data/application_error.dart';
import 'package:pushlog/core/services/pushlog_api_client.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';
import 'package:pushlog/workout/models/repos/abs/workout_repository.dart';
import 'package:pushlog/workout/models/repos/impl/local_workout_repository.dart';

class CloudWorkoutRepository implements WorkoutRepository {
  CloudWorkoutRepository({
    required this.localRepository,
    required this.auth,
    required this.api,
  });

  final LocalWorkoutRepository localRepository;
  final FirebaseAuth auth;
  final PushlogApiClient api;

  WorkoutSnapshot? _memorySnapshot;

  @override
  Future<Either<ApplicationError, WorkoutSnapshot>> loadSnapshot() async {
    try {
      final localSnapshot = (await localRepository.loadSnapshot()).normalized();
      final user = auth.currentUser;
      if (user == null) {
        _memorySnapshot = localSnapshot;
        return Right(localSnapshot);
      }

      Map<String, dynamic>? remoteJson;
      try {
        final response = await api.get('/v1/workout-snapshot');
        final value = response['snapshot'];
        if (value is Map) remoteJson = Map<String, dynamic>.from(value);
      } on PushlogApiException catch (error) {
        if (error.statusCode != 404) rethrow;
      }
      if (remoteJson == null) {
        if (!localSnapshot.isEmpty) {
          final seeded = await _pushRemote(localSnapshot);
          _memorySnapshot = seeded;
          return Right(seeded);
        }

        _memorySnapshot = localSnapshot;
        return Right(localSnapshot);
      }

      final remoteSnapshot = WorkoutSnapshot.fromJson(remoteJson);

      final chosen = localSnapshot.isEmpty
          ? remoteSnapshot.copyWith(
              lastSyncedAt: remoteSnapshot.lastSyncedAt ?? DateTime.now(),
            )
          : await _pushRemote(localSnapshot.mergeWith(remoteSnapshot));

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

      final synced = await _pushRemote(normalized);
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

  Future<WorkoutSnapshot> _pushRemote(WorkoutSnapshot snapshot) async {
    final syncedAt = DateTime.now();
    final remoteSnapshot = snapshot.copyWith(
      lastSyncedAt: syncedAt,
    );

    final now = DateTime.now();
    await api.put(
      '/v1/workout-snapshot',
      body: {
        'snapshot': remoteSnapshot.toJson(),
        'clientContext': {
          'dayKey': _dayKey(now),
          'weekKey': _dayKey(
            DateTime(now.year, now.month, now.day).subtract(
              Duration(days: now.weekday - 1),
            ),
          ),
        },
      },
    );
    await localRepository.saveSnapshot(remoteSnapshot);
    return remoteSnapshot;
  }

  String _dayKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
