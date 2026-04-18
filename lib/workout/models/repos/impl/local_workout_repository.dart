import 'dart:convert';
import 'dart:developer';

import 'package:pushlog/core/services/storage_service.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';

class LocalWorkoutRepository {
  LocalWorkoutRepository({
    required this.storage,
    required this.scopeResolver,
  });

  final StorageService storage;
  final String Function() scopeResolver;

  static const String snapshotKey = 'pushlog.snapshot';
  static const String dayTotalsKey = 'pushlog.day_totals';
  static const String sessionsKey = 'pushlog.sessions';
  static const String preferencesKey =
      'pushlog.preferences';

  Future<WorkoutSnapshot> loadSnapshot() async {
    try {
      final raw = storage.getString(_scoped(snapshotKey));
      if (raw != null) {
        return WorkoutSnapshot.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(raw) as Map,
          ),
        );
      }

      return _loadLegacySnapshot();
    } on Exception catch (error, stackTrace) {
      log(
        'local snapshot load error',
        error: error,
        stackTrace: stackTrace,
      );
      return const WorkoutSnapshot();
    }
  }

  Future<void> saveSnapshot(
    WorkoutSnapshot snapshot,
  ) async {
    await storage.setString(
      _scoped(snapshotKey),
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<void> resetScopedData() async {
    await storage.remove(_scoped(snapshotKey));
    await storage.remove(_scoped(dayTotalsKey));
    await storage.remove(_scoped(sessionsKey));
    await storage.remove(_scoped(preferencesKey));
  }

  Future<String> exportScopedJson() async {
    final snapshot = await loadSnapshot();
    return snapshot.toPrettyJson();
  }

  WorkoutSnapshot _loadLegacySnapshot() {
    final legacySnapshot =
        storage.getString(_scoped(snapshotKey));
    if (legacySnapshot != null) {
      return WorkoutSnapshot.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(legacySnapshot) as Map,
        ),
      );
    }

    final rawDayTotals =
        storage.getString(_legacy(dayTotalsKey));
    final rawSessions =
        storage.getString(_legacy(sessionsKey));
    final rawPreferences =
        storage.getString(_legacy(preferencesKey));

    final dayTotals = rawDayTotals == null
        ? <String, int>{}
        : (jsonDecode(rawDayTotals) as Map<String, dynamic>)
            .map(
              (key, value) => MapEntry(
                key,
                (value as num).toInt(),
              ),
            );

    final sessions = rawSessions == null
        ? <WorkoutSession>[]
        : (jsonDecode(rawSessions) as List<dynamic>)
            .map(
              (item) => WorkoutSession.fromJson(
                Map<String, dynamic>.from(
                  item as Map,
                ),
              ),
            )
            .toList();

    final preferences = rawPreferences == null
        ? const WorkoutPreferences()
        : WorkoutPreferences.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(rawPreferences) as Map,
            ),
          );

    return WorkoutSnapshot(
      dayTotals: dayTotals,
      sessions: sessions,
      preferences: preferences,
    );
  }

  String _scoped(String baseKey) =>
      '$baseKey.${scopeResolver()}';

  String _legacy(String baseKey) => baseKey;
}
