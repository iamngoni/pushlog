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
    return WorkoutSnapshot(
      dayTotals: (json['dayTotals'] as Map<String, dynamic>? ?? const {})
          .map(
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

  Map<String, dynamic> toJson() => {
        'dayTotals': dayTotals,
        'sessions': sessions
            .map((session) => session.toJson())
            .toList(),
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
}
