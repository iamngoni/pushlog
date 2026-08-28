//
//  pushlog
//  workout_session.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:equatable/equatable.dart';

enum WorkoutSource {
  manual,
  live,
}

class WorkoutSession extends Equatable {
  const WorkoutSession({
    required this.id,
    required this.date,
    required this.reps,
    required this.source,
    this.duration,
    this.averageRepDuration,
    this.manualAdjustments = 0,
    this.effortScore,
  });

  factory WorkoutSession.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkoutSession(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      reps: json['reps'] as int,
      source: WorkoutSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => WorkoutSource.manual,
      ),
      duration: json['duration'] != null
          ? Duration(
              microseconds: (json['duration'] as num).toInt(),
            )
          : null,
      averageRepDuration: json['averageRepDuration'] != null
          ? Duration(
              microseconds: (json['averageRepDuration'] as num).toInt(),
            )
          : null,
      manualAdjustments: (json['manualAdjustments'] as int?) ?? 0,
      effortScore: (json['effortScore'] as num?)?.toInt(),
    );
  }

  final String id;
  final DateTime date;
  final int reps;
  final WorkoutSource source;
  final Duration? duration;
  final Duration? averageRepDuration;
  final int manualAdjustments;
  final int? effortScore;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'reps': reps,
    'source': source.name,
    'duration': duration?.inMicroseconds,
    'averageRepDuration': averageRepDuration?.inMicroseconds,
    'manualAdjustments': manualAdjustments,
    'effortScore': effortScore,
  };

  WorkoutSession copyWith({
    String? id,
    DateTime? date,
    int? reps,
    WorkoutSource? source,
    Duration? duration,
    Duration? averageRepDuration,
    int? manualAdjustments,
    int? Function()? effortScore,
  }) => WorkoutSession(
    id: id ?? this.id,
    date: date ?? this.date,
    reps: reps ?? this.reps,
    source: source ?? this.source,
    duration: duration ?? this.duration,
    averageRepDuration: averageRepDuration ?? this.averageRepDuration,
    manualAdjustments: manualAdjustments ?? this.manualAdjustments,
    effortScore: effortScore == null ? this.effortScore : effortScore(),
  );

  @override
  List<Object?> get props => [
    id,
    date,
    reps,
    source,
    duration,
    averageRepDuration,
    manualAdjustments,
    effortScore,
  ];
}
