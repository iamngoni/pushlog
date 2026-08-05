//
//  pushlog
//  workout_state.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

part of 'workout_bloc.dart';

sealed class WorkoutState extends Equatable {
  const WorkoutState();
}

class WorkoutInitial extends WorkoutState {
  const WorkoutInitial();

  @override
  List<Object?> get props => [];
}

class WorkoutLoading extends WorkoutState {
  const WorkoutLoading();

  @override
  List<Object?> get props => [];
}

class PendingUndo extends Equatable {
  const PendingUndo({
    required this.sessionId,
    required this.reps,
    required this.date,
  });

  final String sessionId;
  final int reps;
  final DateTime date;

  @override
  List<Object?> get props => [sessionId, reps, date];
}

class WorkoutLoaded extends WorkoutState {
  const WorkoutLoaded({
    required this.dayTotals,
    required this.sessions,
    required this.preferences,
    this.lastSyncedAt,
    this.isSyncing = false,
    this.syncError,
    this.pendingUndo,
  });

  final Map<String, int> dayTotals;
  final List<WorkoutSession> sessions;
  final WorkoutPreferences preferences;
  final DateTime? lastSyncedAt;
  final bool isSyncing;
  final String? syncError;
  final PendingUndo? pendingUndo;

  int get todayCount {
    final key = WorkoutBloc.dayKey(DateTime.now());
    return dayTotals[key] ?? 0;
  }

  int get streak {
    var cursor = startOfDay(DateTime.now());
    final todayKey = WorkoutBloc.dayKey(cursor);
    if ((dayTotals[todayKey] ?? 0) == 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while ((dayTotals[WorkoutBloc.dayKey(cursor)] ?? 0) > 0) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  PlannedSession? get todayPlan {
    return preferences.trainingPlan?.sessionFor(DateTime.now());
  }

  int get plannedSessionsThisWeek {
    final plan = preferences.trainingPlan;
    if (plan == null) return 0;
    final now = startOfDay(DateTime.now());
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(DateTime.daysPerWeek, (offset) {
      return monday.add(Duration(days: offset));
    }).where(plan.isTrainingDay).length;
  }

  int get completedPlannedSessionsThisWeek {
    final plan = preferences.trainingPlan;
    if (plan == null) return 0;
    final now = startOfDay(DateTime.now());
    final monday = now.subtract(Duration(days: now.weekday - 1));
    var completed = 0;
    for (var offset = 0; offset < DateTime.daysPerWeek; offset++) {
      final date = monday.add(Duration(days: offset));
      if (date.isAfter(now) || !plan.isTrainingDay(date)) continue;
      if ((dayTotals[WorkoutBloc.dayKey(date)] ?? 0) > 0) completed++;
    }
    return completed;
  }

  String get consistencyValue {
    return switch (preferences.trainingPlan?.profile.consistencyPreference) {
      ConsistencyPreference.weeklyPlan ||
      ConsistencyPreference.scheduledSessions =>
        '$completedPlannedSessionsThisWeek/$plannedSessionsThisWeek',
      ConsistencyPreference.none => '$activeDaysThisWeek',
      null => streak.toString().padLeft(2, '0'),
    };
  }

  String get consistencyLabel {
    return switch (preferences.trainingPlan?.profile.consistencyPreference) {
      ConsistencyPreference.weeklyPlan => 'THIS WEEK',
      ConsistencyPreference.scheduledSessions => 'ON PLAN',
      ConsistencyPreference.none => 'ACTIVE DAYS',
      null => 'STREAK',
    };
  }

  int get activeDaysThisWeek {
    final now = startOfDay(DateTime.now());
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(DateTime.daysPerWeek, (index) {
      final date = monday.add(Duration(days: index));
      return date.isAfter(now) ? 0 : (dayTotals[WorkoutBloc.dayKey(date)] ?? 0);
    }).where((count) => count > 0).length;
  }

  int get weekCount {
    final now = startOfDay(DateTime.now());
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(now.weekday, (index) {
      final date = monday.add(Duration(days: index));
      return dayTotals[WorkoutBloc.dayKey(date)] ?? 0;
    }).fold(0, (total, count) => total + count);
  }

  int get bestDay {
    if (dayTotals.values.isEmpty) return 0;
    return dayTotals.values.reduce(
      (a, b) => a > b ? a : b,
    );
  }

  int get totalAllTime => dayTotals.values.fold(0, (sum, v) => sum + v);

  List<DaySummary> get weekSummary {
    final today = startOfDay(DateTime.now());
    return List.generate(7, (i) {
      final date = today.subtract(Duration(days: 6 - i));
      final key = WorkoutBloc.dayKey(date);
      return DaySummary(
        date: date,
        count: dayTotals[key] ?? 0,
        isToday: i == 6,
      );
    });
  }

  List<HistoryEntry> get historyEntries {
    final todayKey = WorkoutBloc.dayKey(DateTime.now());
    final entries =
        dayTotals.entries
            .map((e) {
              final date = parseDate(e.key);
              if (date == null) return null;
              return HistoryEntry(
                date: date,
                count: e.value,
                isToday: e.key == todayKey,
              );
            })
            .whereType<HistoryEntry>()
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  WorkoutLoaded copyWith({
    Map<String, int>? dayTotals,
    List<WorkoutSession>? sessions,
    WorkoutPreferences? preferences,
    DateTime? lastSyncedAt,
    bool? isSyncing,
    String? Function()? syncError,
    PendingUndo? Function()? pendingUndo,
  }) => WorkoutLoaded(
    dayTotals: dayTotals ?? this.dayTotals,
    sessions: sessions ?? this.sessions,
    preferences: preferences ?? this.preferences,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    isSyncing: isSyncing ?? this.isSyncing,
    syncError: syncError != null ? syncError() : this.syncError,
    pendingUndo: pendingUndo != null ? pendingUndo() : this.pendingUndo,
  );

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime? parseDate(String key) {
    try {
      return DateTime.parse(key);
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    dayTotals,
    sessions,
    preferences,
    lastSyncedAt,
    isSyncing,
    syncError,
    pendingUndo,
  ];
}

class WorkoutError extends WorkoutState {
  const WorkoutError(this.error);

  final ApplicationError error;

  @override
  List<Object?> get props => [error];
}
