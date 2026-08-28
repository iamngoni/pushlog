//
//  pushlog
//  workout_bloc.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:developer' as dev;
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:pushlog/core/models/data/application_error.dart';
import 'package:pushlog/core/services/reminder_service.dart';
import 'package:pushlog/training/models/training_plan.dart';
import 'package:pushlog/workout/models/data/day_summary.dart';
import 'package:pushlog/workout/models/data/history_entry.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';
import 'package:pushlog/workout/models/repos/abs/workout_repository.dart';

part 'workout_event.dart';
part 'workout_state.dart';

@injectable
class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {
  WorkoutBloc({
    required WorkoutRepository repository,
    required ReminderService reminderService,
  }) : _repository = repository,
       _reminderService = reminderService,
       super(const WorkoutInitial()) {
    on<LoadWorkoutDataEvent>(_onLoadWorkoutData);
    on<AddManualRepsEvent>(_onAddManualReps);
    on<UndoLastEntryEvent>(_onUndoLastEntry);
    on<SaveLiveSessionEvent>(_onSaveLiveSession);
    on<DeleteSessionEvent>(_onDeleteSession);
    on<UpdateSessionRepsEvent>(_onUpdateSessionReps);
    on<UpdatePreferencesEvent>(_onUpdatePreferences);
    on<SyncWorkoutDataEvent>(_onSyncWorkoutData);
    on<ResetWorkoutDataEvent>(_onResetWorkoutData);
  }

  final WorkoutRepository _repository;
  final ReminderService _reminderService;

  static final _random = Random.secure();

  static String generateId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _onLoadWorkoutData(
    LoadWorkoutDataEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(const WorkoutLoading());
    try {
      final result = await _repository.loadSnapshot();
      final loadedState = result.fold<WorkoutLoaded?>(
        (error) {
          emit(WorkoutError(error));
          return null;
        },
        _stateFromSnapshot,
      );
      if (loadedState == null) return;

      emit(loadedState);
      await _syncReminders(
        loadedState.preferences,
        loadedState.dayTotals,
      );
    } on Exception catch (e, s) {
      dev.log(
        'LoadWorkoutData error',
        error: e,
        stackTrace: s,
      );
      emit(WorkoutError(ApplicationError.unknownError()));
    }
  }

  Future<void> _onAddManualReps(
    AddManualRepsEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    if (state is! WorkoutLoaded) return;
    if (event.reps <= 0) return;

    final current = state as WorkoutLoaded;
    final now = DateTime.now();
    final key = dayKey(now);
    final sessionId = generateId();

    final session = WorkoutSession(
      id: sessionId,
      date: now,
      reps: event.reps,
      source: WorkoutSource.manual,
    );

    final updatedTotals = Map<String, int>.from(current.dayTotals);
    updatedTotals[key] = (updatedTotals[key] ?? 0) + event.reps;

    final updatedSessions = [
      session,
      ...current.sessions,
    ]..sort((a, b) => b.date.compareTo(a.date));

    final updatedState = current.copyWith(
      dayTotals: updatedTotals,
      sessions: updatedSessions,
      pendingUndo: () => PendingUndo(
        sessionId: sessionId,
        reps: event.reps,
        date: now,
      ),
    );

    emit(updatedState);
    await _persistState(updatedState, emit);
  }

  Future<void> _onUndoLastEntry(
    UndoLastEntryEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    if (state is! WorkoutLoaded) return;

    final current = state as WorkoutLoaded;
    final undo = current.pendingUndo;
    if (undo == null) return;

    final sessionIndex = current.sessions.indexWhere(
      (s) => s.id == undo.sessionId && s.source == WorkoutSource.manual,
    );

    final updatedSessions = List<WorkoutSession>.from(current.sessions);
    if (sessionIndex >= 0) {
      updatedSessions.removeAt(sessionIndex);
    }

    final key = dayKey(undo.date);
    final updatedTotals = Map<String, int>.from(current.dayTotals);
    final updated = (updatedTotals[key] ?? 0) - undo.reps;
    if (updated <= 0) {
      updatedTotals.remove(key);
    } else {
      updatedTotals[key] = updated;
    }

    final updatedState = current.copyWith(
      dayTotals: updatedTotals,
      sessions: updatedSessions,
      pendingUndo: () => null,
    );

    emit(updatedState);
    await _persistState(updatedState, emit);
  }

  Future<void> _onSaveLiveSession(
    SaveLiveSessionEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    if (state is! WorkoutLoaded) return;
    if (event.reps <= 0) return;

    final current = state as WorkoutLoaded;
    final now = DateTime.now();
    final key = dayKey(now);

    final session = WorkoutSession(
      id: event.sessionId ?? generateId(),
      date: now,
      reps: event.reps,
      source: WorkoutSource.live,
      duration: event.duration,
      averageRepDuration: event.avgRepDuration,
      manualAdjustments: event.manualAdjustments,
      effortScore: event.effortScore,
    );

    final updatedTotals = Map<String, int>.from(current.dayTotals);
    updatedTotals[key] = (updatedTotals[key] ?? 0) + event.reps;

    final updatedSessions = [
      session,
      ...current.sessions,
    ]..sort((a, b) => b.date.compareTo(a.date));

    final updatedState = current.copyWith(
      dayTotals: updatedTotals,
      sessions: updatedSessions,
      pendingUndo: () => null,
    );

    emit(updatedState);
    await _persistState(updatedState, emit);
  }

  Future<void> _onDeleteSession(
    DeleteSessionEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    if (state is! WorkoutLoaded) return;

    final current = state as WorkoutLoaded;
    final sessionIndex = current.sessions.indexWhere(
      (s) => s.id == event.sessionId,
    );
    if (sessionIndex < 0) return;

    final session = current.sessions[sessionIndex];
    final key = dayKey(session.date);

    final updatedSessions = List<WorkoutSession>.from(current.sessions)
      ..removeAt(sessionIndex);

    final updatedTotals = Map<String, int>.from(current.dayTotals);
    final updated = (updatedTotals[key] ?? 0) - session.reps;
    if (updated <= 0) {
      updatedTotals.remove(key);
    } else {
      updatedTotals[key] = updated;
    }

    var pendingUndo = current.pendingUndo;
    if (pendingUndo?.sessionId == event.sessionId) {
      pendingUndo = null;
    }

    final updatedState = current.copyWith(
      dayTotals: updatedTotals,
      sessions: updatedSessions,
      pendingUndo: () => pendingUndo,
    );

    emit(updatedState);
    await _persistState(updatedState, emit);
  }

  Future<void> _onUpdateSessionReps(
    UpdateSessionRepsEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    if (state is! WorkoutLoaded) return;
    if (event.reps <= 0) {
      add(DeleteSessionEvent(event.sessionId));
      return;
    }

    final current = state as WorkoutLoaded;
    final sessionIndex = current.sessions.indexWhere(
      (s) => s.id == event.sessionId,
    );
    if (sessionIndex < 0) return;

    final existing = current.sessions[sessionIndex];
    if (existing.reps == event.reps) return;

    final key = dayKey(existing.date);
    final delta = event.reps - existing.reps;

    final updatedSessions = List<WorkoutSession>.from(current.sessions);
    updatedSessions[sessionIndex] = existing.copyWith(reps: event.reps);

    final updatedTotals = Map<String, int>.from(current.dayTotals);
    final updated = (updatedTotals[key] ?? 0) + delta;
    if (updated <= 0) {
      updatedTotals.remove(key);
    } else {
      updatedTotals[key] = updated;
    }

    var pendingUndo = current.pendingUndo;
    if (pendingUndo?.sessionId == event.sessionId) {
      pendingUndo = null;
    }

    final updatedState = current.copyWith(
      dayTotals: updatedTotals,
      sessions: updatedSessions,
      pendingUndo: () => pendingUndo,
    );

    emit(updatedState);
    await _persistState(updatedState, emit);
  }

  Future<void> _onUpdatePreferences(
    UpdatePreferencesEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    if (state is! WorkoutLoaded) return;

    final current = state as WorkoutLoaded;
    final updatedState = current.copyWith(
      preferences: event.preferences,
      syncError: () => null,
    );
    emit(updatedState);
    await _persistState(updatedState, emit);
  }

  Future<void> _onSyncWorkoutData(
    SyncWorkoutDataEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    if (state is! WorkoutLoaded) return;

    final current = state as WorkoutLoaded;
    final syncingState = current.copyWith(
      isSyncing: true,
      syncError: () => null,
    );
    emit(syncingState);
    await _persistState(syncingState, emit);
  }

  Future<void> _onResetWorkoutData(
    ResetWorkoutDataEvent event,
    Emitter<WorkoutState> emit,
  ) async {
    emit(const WorkoutLoading());
    final result = await _repository.resetSnapshot();
    final loadedState = result.fold<WorkoutLoaded?>(
      (error) {
        emit(WorkoutError(error));
        return null;
      },
      _stateFromSnapshot,
    );
    if (loadedState == null) return;

    emit(loadedState);
    await _syncReminders(
      loadedState.preferences,
      loadedState.dayTotals,
    );
  }

  WorkoutLoaded _stateFromSnapshot(
    WorkoutSnapshot snapshot,
  ) {
    final normalized = snapshot.normalized();
    final sessions = List<WorkoutSession>.from(
      normalized.sessions,
    )..sort((a, b) => b.date.compareTo(a.date));

    return WorkoutLoaded(
      dayTotals: Map<String, int>.from(normalized.dayTotals),
      sessions: sessions,
      preferences: normalized.preferences,
      lastSyncedAt: normalized.lastSyncedAt,
    );
  }

  WorkoutSnapshot _snapshotFromState(
    WorkoutLoaded state,
  ) {
    return WorkoutSnapshot(
      dayTotals: Map<String, int>.from(state.dayTotals),
      sessions: List<WorkoutSession>.from(state.sessions),
      preferences: state.preferences,
      lastSyncedAt: state.lastSyncedAt,
      updatedAt: DateTime.now(),
    ).normalized();
  }

  Future<void> _persistState(
    WorkoutLoaded state,
    Emitter<WorkoutState> emit,
  ) async {
    await _syncReminders(state.preferences, state.dayTotals);
    final result = await _repository.saveSnapshot(
      _snapshotFromState(state),
    );
    result.fold(
      (error) => emit(
        state.copyWith(
          isSyncing: false,
          syncError: () => error.message,
        ),
      ),
      (snapshot) => emit(
        state.copyWith(
          lastSyncedAt: snapshot.lastSyncedAt,
          isSyncing: false,
          syncError: () => null,
        ),
      ),
    );
  }

  Future<void> _syncReminders(
    WorkoutPreferences preferences,
    Map<String, int> dayTotals,
  ) async {
    try {
      await _reminderService.syncPreferences(
        preferences,
        dayTotals: dayTotals,
      );
    } on Exception catch (error, stackTrace) {
      dev.log(
        'Reminder sync error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
