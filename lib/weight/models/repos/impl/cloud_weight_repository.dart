import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:pushlog/core/models/data/application_error.dart';
import 'package:pushlog/core/services/pushlog_api_client.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/models/repos/abs/weight_repository.dart';
import 'package:pushlog/weight/models/repos/impl/local_weight_repository.dart';

class CloudWeightRepository implements WeightRepository {
  CloudWeightRepository({required this.local, required this.api});

  final LocalWeightRepository local;
  final PushlogApiClient api;

  @override
  Future<Either<ApplicationError, List<WeightEntry>>> loadEntries() async {
    try {
      await _flushReset();
      await _pushDirty(local.loadEntries());
      // Reload after the push. The pre-push list is still marked dirty, and
      // merging that list would put the stale day back over a newer remote.
      final afterPush = local.loadEntries();
      final payload = await api.get('/v1/weight/entries');
      final remote = _entriesFromPayload(payload);
      // Re-read after the fetch. A day logged while it was in flight is
      // newer than the remote list, so it must survive the merge.
      final merged = _merge(afterPush, local.loadEntries(), remote);
      await local.saveEntries(merged);
      return Right(merged);
    } on Exception catch (error, stackTrace) {
      log('weight load kept local copy', error: error, stackTrace: stackTrace);
      return Right(local.loadEntries());
    }
  }

  @override
  Future<Either<ApplicationError, WeightEntry>> saveEntry(
    WeightEntry entry,
  ) async {
    final existing = local.loadEntries();
    final next = [
      for (final item in existing)
        if (item.recordedOn != entry.recordedOn) item,
      entry.copyWith(dirty: true),
    ]..sort((a, b) => a.recordedOn.compareTo(b.recordedOn));
    await local.saveEntries(next);
    try {
      await _flushReset();
      final payload = await api.put(
        '/v1/weight/entries',
        body: {
          'recordedOn': entry.recordedOn,
          'weightGrams': entry.weightGrams,
        },
      );
      final saved = entry.copyWith(
        updatedAt: payload['updatedAt'] as String? ?? entry.updatedAt,
        dirty: false,
      );
      // Re-read rather than reuse `next`: a pull may have written newer days
      // while the put was in flight.
      // A re-log of the same day during the put stays dirty.
      bool isSaved(WeightEntry item) =>
          item.recordedOn == saved.recordedOn &&
          item.weightGrams == saved.weightGrams;
      await local.saveEntries([
        for (final item in local.loadEntries()) isSaved(item) ? saved : item,
      ]);
      return Right(saved);
    } on Exception catch (error, stackTrace) {
      log('weight save stayed local', error: error, stackTrace: stackTrace);
      return Right(entry.copyWith(dirty: true));
    }
  }

  @override
  Future<WeightSettings> loadSettings() async {
    final localSettings = local.loadSettings();
    if (localSettings.dirty) {
      final saved = await saveSettings(localSettings);
      return saved.getOrElse(() => localSettings);
    }
    try {
      await _flushReset();
      final payload = await api.get('/v1/weight/settings');
      final remote = WeightSettings.fromJson(payload);
      await local.saveSettings(remote);
      return remote;
    } on Exception {
      return localSettings;
    }
  }

  @override
  Future<Either<ApplicationError, WeightSettings>> saveSettings(
    WeightSettings settings,
  ) async {
    final pending = settings.copyWith(dirty: true);
    await local.saveSettings(pending);
    try {
      await _flushReset();
      final payload = await api.put(
        '/v1/weight/settings',
        body: {
          'unit': pending.unit.name,
          'goal': pending.goal.name,
          'shareProgress': pending.shareProgress,
          'shareLatestWeight': pending.shareLatestWeight,
        },
      );
      final saved = WeightSettings.fromJson(payload);
      await local.saveSettings(saved);
      return Right(saved);
    } on Exception catch (error, stackTrace) {
      log('weight settings stayed local', error: error, stackTrace: stackTrace);
      return Right(pending);
    }
  }

  @override
  Future<Either<ApplicationError, List<FriendWeighIn>>> loadFriendsBoard({
    required String asOf,
  }) async {
    try {
      final payload = await api.get(
        '/v1/weight/friends',
        query: {'asOf': asOf},
      );
      final raw = payload['entries'];
      if (raw is! List) return const Right([]);
      return Right(
        raw
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (item) => FriendWeighIn.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(),
      );
    } on Exception catch (error) {
      return Left(
        ApplicationError(message: error.toString(), code: 'weight_board'),
      );
    }
  }

  /// Clears the device copy now and the cloud copy as soon as it can.
  ///
  /// The pending mark is written before the delete is sent, so an offline
  /// reset, or one sent before the Worker has the route, is retried on the
  /// next sync instead of being pulled back down.
  @override
  Future<void> reset() async {
    await local.reset();
    await local.markResetPending();
    try {
      await _flushReset();
    } on Exception catch (error, stackTrace) {
      log('weight reset waits for sync', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> clearLocal({required String uid}) => local.reset(scope: uid);

  @override
  List<Map<String, dynamic>> exportEntries() {
    // `dirty` is sync bookkeeping, not the user's data.
    return local
        .loadEntries()
        .map((entry) => entry.toJson()..remove('dirty'))
        .toList();
  }

  /// Throws while a reset still waits on the cloud, so every sync path stays
  /// local rather than pulling back what the user just cleared.
  Future<void> _flushReset() async {
    if (!local.resetPending) return;
    await api.delete('/v1/weight');
    await local.clearResetPending();
  }

  Future<void> _pushDirty(List<WeightEntry> entries) async {
    for (final entry in entries.where((item) => item.dirty)) {
      await saveEntry(entry);
    }
  }

  List<WeightEntry> _entriesFromPayload(Map<String, dynamic> payload) {
    final raw = payload['entries'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => WeightEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<WeightEntry> _merge(
    List<WeightEntry> beforeFetch,
    List<WeightEntry> afterFetch,
    List<WeightEntry> remote,
  ) {
    final byDay = {for (final entry in remote) entry.recordedOn: entry};
    final unchanged = beforeFetch.toSet();
    for (final entry in afterFetch) {
      if (entry.dirty || !unchanged.contains(entry)) {
        byDay[entry.recordedOn] = entry;
      }
    }
    final merged = byDay.values.toList()
      ..sort((a, b) => a.recordedOn.compareTo(b.recordedOn));
    return merged;
  }
}
