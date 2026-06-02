import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';

class WorkoutSnapshot extends Equatable {
  const WorkoutSnapshot({
    this.dayTotals = const {},
    this.sessions = const [],
    this.preferences = const WorkoutPreferences(),
    this.updatedAt,
    this.lastSyncedAt,
  });

  factory WorkoutSnapshot.fromJson(Map<String, dynamic> json) {
    final snapshot = WorkoutSnapshot(
      dayTotals: (json['dayTotals'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(
          key,
          (value as num).toInt(),
        ),
      ),
      sessions: (json['sessions'] as List<dynamic>? ?? const [])
          .map(
            (session) => WorkoutSession.fromJson(
              Map<String, dynamic>.from(session as Map),
            ),
          )
          .toList(),
      preferences: WorkoutPreferences.fromJson(
        Map<String, dynamic>.from(
          json['preferences'] as Map? ?? const {},
        ),
      ),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.tryParse(
              json['lastSyncedAt'] as String,
            )
          : null,
    );
    return snapshot.sessions.isEmpty ? snapshot : snapshot.normalized();
  }

  final Map<String, int> dayTotals;
  final List<WorkoutSession> sessions;
  final WorkoutPreferences preferences;
  final DateTime? updatedAt;
  final DateTime? lastSyncedAt;

  bool get isEmpty =>
      dayTotals.isEmpty &&
      sessions.isEmpty &&
      preferences == const WorkoutPreferences();

  WorkoutSnapshot normalized() {
    if (sessions.isEmpty) {
      return copyWith(dayTotals: Map<String, int>.from(dayTotals));
    }

    final normalizedSessions = List<WorkoutSession>.from(sessions)
      ..sort((left, right) => right.date.compareTo(left.date));

    return copyWith(
      dayTotals: _totalsFromSessions(normalizedSessions),
      sessions: normalizedSessions,
    );
  }

  WorkoutSnapshot mergeWith(WorkoutSnapshot other) {
    final sessionsById = <String, WorkoutSession>{
      for (final session in other.sessions) session.id: session,
      for (final session in sessions) session.id: session,
    };
    final mergedSessions = sessionsById.values.toList()
      ..sort((left, right) => right.date.compareTo(left.date));
    final newestSnapshot = _isAfterOrSame(updatedAt, other.updatedAt)
        ? this
        : other;

    return WorkoutSnapshot(
      dayTotals: _totalsFromSessions(mergedSessions),
      sessions: mergedSessions,
      preferences: newestSnapshot.preferences,
      updatedAt: _latest(updatedAt, other.updatedAt),
      lastSyncedAt: _latest(lastSyncedAt, other.lastSyncedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'dayTotals': dayTotals,
    'sessions': sessions.map((session) => session.toJson()).toList(),
    'preferences': preferences.toJson(),
    'updatedAt': updatedAt?.toIso8601String(),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
  };

  String toPrettyJson() => const JsonEncoder.withIndent(
    '  ',
  ).convert(toJson());

  WorkoutSnapshot copyWith({
    Map<String, int>? dayTotals,
    List<WorkoutSession>? sessions,
    WorkoutPreferences? preferences,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
  }) {
    return WorkoutSnapshot(
      dayTotals: dayTotals ?? this.dayTotals,
      sessions: sessions ?? this.sessions,
      preferences: preferences ?? this.preferences,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [
    dayTotals,
    sessions,
    preferences,
    updatedAt,
    lastSyncedAt,
  ];

  static Map<String, int> _totalsFromSessions(
    List<WorkoutSession> sessions,
  ) {
    final totals = <String, int>{};
    for (final session in sessions) {
      final key = _dayKey(session.date);
      totals[key] = (totals[key] ?? 0) + session.reps;
    }
    return totals;
  }

  static String _dayKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime? _latest(DateTime? left, DateTime? right) {
    if (left == null) return right;
    if (right == null) return left;
    return left.isAfter(right) ? left : right;
  }

  static bool _isAfterOrSame(DateTime? left, DateTime? right) {
    if (left == null) return right == null;
    if (right == null) return true;
    return left.isAfter(right) || left.isAtSameMomentAs(right);
  }
}
