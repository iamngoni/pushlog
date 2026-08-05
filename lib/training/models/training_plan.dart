import 'dart:math';

import 'package:equatable/equatable.dart';

enum TrainingGoal {
  buildHabit,
  increaseMaximum,
  improveEndurance,
  maintainAbility,
  custom,
}

enum TrainingExperience { newToTraining, regular, experienced }

enum BaselineSource { recentResult, guidedAssessment, conservativeStart }

enum ConsistencyPreference { weeklyPlan, scheduledSessions, none }

enum CoachingStyle { calm, energetic, minimal }

enum SessionDifficulty { easy, right, hard, painful }

class TrainingProfile extends Equatable {
  const TrainingProfile({
    required this.goal,
    required this.experience,
    required this.baselineSource,
    required this.baselineMaxReps,
    required this.targetMaxReps,
    required this.durationWeeks,
    required this.sessionsPerWeek,
    required this.preferredWeekdays,
    required this.consistencyPreference,
    required this.coachingStyle,
  });

  factory TrainingProfile.fromJson(Map<String, dynamic> json) {
    final experience = _enumFromName(
      TrainingExperience.values,
      json['experience'] as String?,
      TrainingExperience.newToTraining,
    );
    final sessionsPerWeek = _boundedInt(
      json['sessionsPerWeek'],
      minimum: 2,
      maximum: 5,
      fallback: _defaultSessionsFor(experience),
    );

    return TrainingProfile(
      goal: _enumFromName(
        TrainingGoal.values,
        json['goal'] as String?,
        TrainingGoal.buildHabit,
      ),
      experience: experience,
      baselineSource: _enumFromName(
        BaselineSource.values,
        json['baselineSource'] as String?,
        BaselineSource.recentResult,
      ),
      baselineMaxReps: _boundedInt(
        json['baselineMaxReps'],
        minimum: 1,
        maximum: 999,
        fallback: 5,
      ),
      targetMaxReps: _boundedInt(
        json['targetMaxReps'],
        minimum: 1,
        maximum: 999,
        fallback: 10,
      ),
      durationWeeks: _boundedInt(
        json['durationWeeks'],
        minimum: 4,
        maximum: 52,
        fallback: 12,
      ),
      sessionsPerWeek: sessionsPerWeek,
      preferredWeekdays: _normalizedWeekdays(
        json['preferredWeekdays'],
        sessionsPerWeek,
      ),
      consistencyPreference: _enumFromName(
        ConsistencyPreference.values,
        json['consistencyPreference'] as String?,
        ConsistencyPreference.weeklyPlan,
      ),
      coachingStyle: _enumFromName(
        CoachingStyle.values,
        json['coachingStyle'] as String?,
        CoachingStyle.calm,
      ),
    );
  }

  final TrainingGoal goal;
  final TrainingExperience experience;
  final BaselineSource baselineSource;
  final int baselineMaxReps;
  final int targetMaxReps;
  final int durationWeeks;
  final int sessionsPerWeek;
  final List<int> preferredWeekdays;
  final ConsistencyPreference consistencyPreference;
  final CoachingStyle coachingStyle;

  Map<String, dynamic> toJson() => {
    'goal': goal.name,
    'experience': experience.name,
    'baselineSource': baselineSource.name,
    'baselineMaxReps': baselineMaxReps,
    'targetMaxReps': targetMaxReps,
    'durationWeeks': durationWeeks,
    'sessionsPerWeek': sessionsPerWeek,
    'preferredWeekdays': preferredWeekdays,
    'consistencyPreference': consistencyPreference.name,
    'coachingStyle': coachingStyle.name,
  };

  TrainingProfile copyWith({
    TrainingGoal? goal,
    TrainingExperience? experience,
    BaselineSource? baselineSource,
    int? baselineMaxReps,
    int? targetMaxReps,
    int? durationWeeks,
    int? sessionsPerWeek,
    List<int>? preferredWeekdays,
    ConsistencyPreference? consistencyPreference,
    CoachingStyle? coachingStyle,
  }) {
    final resolvedExperience = experience ?? this.experience;
    final resolvedSessions = sessionsPerWeek ?? this.sessionsPerWeek;
    return TrainingProfile(
      goal: goal ?? this.goal,
      experience: resolvedExperience,
      baselineSource: baselineSource ?? this.baselineSource,
      baselineMaxReps: baselineMaxReps ?? this.baselineMaxReps,
      targetMaxReps: targetMaxReps ?? this.targetMaxReps,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      sessionsPerWeek: resolvedSessions,
      preferredWeekdays:
          preferredWeekdays ??
          (sessionsPerWeek == null
              ? this.preferredWeekdays
              : defaultWeekdays(resolvedSessions)),
      consistencyPreference:
          consistencyPreference ?? this.consistencyPreference,
      coachingStyle: coachingStyle ?? this.coachingStyle,
    );
  }

  static List<int> defaultWeekdays(int sessionsPerWeek) {
    return switch (sessionsPerWeek.clamp(2, 5)) {
      2 => const [DateTime.monday, DateTime.thursday],
      3 => const [DateTime.monday, DateTime.wednesday, DateTime.friday],
      4 => const [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.saturday,
      ],
      _ => const [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.friday,
        DateTime.saturday,
      ],
    };
  }

  @override
  List<Object?> get props => [
    goal,
    experience,
    baselineSource,
    baselineMaxReps,
    targetMaxReps,
    durationWeeks,
    sessionsPerWeek,
    preferredWeekdays,
    consistencyPreference,
    coachingStyle,
  ];
}

class TrainingPlan extends Equatable {
  const TrainingPlan({
    required this.profile,
    required this.startDate,
    required this.createdAt,
    this.algorithmVersion = currentAlgorithmVersion,
  });

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    final startDate = DateTime.tryParse(json['startDate'] as String? ?? '');
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    return TrainingPlan(
      profile: TrainingProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map? ?? const {}),
      ),
      startDate: _dateOnly(startDate ?? DateTime.now()),
      createdAt: createdAt ?? startDate ?? DateTime.now(),
      algorithmVersion: _boundedInt(
        json['algorithmVersion'],
        minimum: 1,
        maximum: currentAlgorithmVersion,
        fallback: 1,
      ),
    );
  }

  static const int currentAlgorithmVersion = 1;

  final TrainingProfile profile;
  final DateTime startDate;
  final DateTime createdAt;
  final int algorithmVersion;

  DateTime get endDate => startDate.add(
    Duration(days: profile.durationWeeks * DateTime.daysPerWeek - 1),
  );

  bool isTrainingDay(DateTime date) {
    final day = _dateOnly(date);
    if (day.isBefore(startDate) || day.isAfter(endDate)) return false;
    return profile.preferredWeekdays.contains(day.weekday);
  }

  int weekIndexFor(DateTime date) {
    final difference = _dateOnly(date).difference(startDate).inDays;
    if (difference <= 0) return 0;
    return (difference ~/ DateTime.daysPerWeek).clamp(
      0,
      profile.durationWeeks - 1,
    );
  }

  int capacityForWeek(int weekIndex) {
    if (profile.durationWeeks <= 1) return profile.targetMaxReps;
    final boundedWeek = weekIndex.clamp(0, profile.durationWeeks - 1);
    final progress = boundedWeek / (profile.durationWeeks - 1);
    final delta = profile.targetMaxReps - profile.baselineMaxReps;
    return max(1, (profile.baselineMaxReps + delta * progress).round());
  }

  PlannedSession sessionFor(DateTime date) {
    final weekIndex = weekIndexFor(date);
    final capacity = capacityForWeek(weekIndex);
    final setCount = _setCount(profile.experience);
    final setFraction = _workingSetFraction(profile.goal);
    final maximumWorkingReps = max(1, capacity - 1);
    final repsPerSet = min(
      maximumWorkingReps,
      max(1, (capacity * setFraction).floor()),
    );

    return PlannedSession(
      date: _dateOnly(date),
      isTrainingDay: isTrainingDay(date),
      weekIndex: weekIndex,
      weekNumber: weekIndex + 1,
      sets: setCount,
      repsPerSet: repsPerSet,
      estimatedCapacity: capacity,
      isAssessmentWeek: (weekIndex + 1) % 4 == 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'profile': profile.toJson(),
    'startDate': startDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'algorithmVersion': algorithmVersion,
  };

  TrainingPlan copyWith({
    TrainingProfile? profile,
    DateTime? startDate,
    DateTime? createdAt,
    int? algorithmVersion,
  }) => TrainingPlan(
    profile: profile ?? this.profile,
    startDate: startDate == null ? this.startDate : _dateOnly(startDate),
    createdAt: createdAt ?? this.createdAt,
    algorithmVersion: algorithmVersion ?? this.algorithmVersion,
  );

  @override
  List<Object?> get props => [profile, startDate, createdAt, algorithmVersion];
}

class PlannedSession extends Equatable {
  const PlannedSession({
    required this.date,
    required this.isTrainingDay,
    required this.weekIndex,
    required this.weekNumber,
    required this.sets,
    required this.repsPerSet,
    required this.estimatedCapacity,
    required this.isAssessmentWeek,
  });

  final DateTime date;
  final bool isTrainingDay;
  final int weekIndex;
  final int weekNumber;
  final int sets;
  final int repsPerSet;
  final int estimatedCapacity;
  final bool isAssessmentWeek;

  int get totalReps => isTrainingDay ? sets * repsPerSet : 0;

  @override
  List<Object?> get props => [
    date,
    isTrainingDay,
    weekIndex,
    weekNumber,
    sets,
    repsPerSet,
    estimatedCapacity,
    isAssessmentWeek,
  ];
}

T _enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}

int _boundedInt(
  Object? value, {
  required int minimum,
  required int maximum,
  required int fallback,
}) {
  final number = value is num ? value.toInt() : fallback;
  return number.clamp(minimum, maximum);
}

int _defaultSessionsFor(TrainingExperience experience) {
  return switch (experience) {
    TrainingExperience.newToTraining => 2,
    TrainingExperience.regular => 3,
    TrainingExperience.experienced => 4,
  };
}

List<int> _normalizedWeekdays(Object? raw, int sessionsPerWeek) {
  final weekdays =
      (raw as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .where(
            (value) => value >= DateTime.monday && value <= DateTime.sunday,
          )
          .toSet()
          .toList()
        ..sort();

  if (weekdays.length != sessionsPerWeek) {
    return TrainingProfile.defaultWeekdays(sessionsPerWeek);
  }
  return weekdays;
}

int _setCount(TrainingExperience experience) {
  return switch (experience) {
    TrainingExperience.newToTraining => 2,
    TrainingExperience.regular => 3,
    TrainingExperience.experienced => 3,
  };
}

double _workingSetFraction(TrainingGoal goal) {
  return switch (goal) {
    TrainingGoal.buildHabit => 0.40,
    TrainingGoal.increaseMaximum => 0.50,
    TrainingGoal.improveEndurance => 0.55,
    TrainingGoal.maintainAbility => 0.45,
    TrainingGoal.custom => 0.50,
  };
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
