//
//  pushlog
//  workout_event.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

part of 'workout_bloc.dart';

abstract class WorkoutEvent extends Equatable {
  const WorkoutEvent();
}

class LoadWorkoutDataEvent extends WorkoutEvent {
  const LoadWorkoutDataEvent();

  @override
  List<Object?> get props => [];
}

class AddManualRepsEvent extends WorkoutEvent {
  const AddManualRepsEvent(this.reps);

  final int reps;

  @override
  List<Object?> get props => [reps];
}

class UndoLastEntryEvent extends WorkoutEvent {
  const UndoLastEntryEvent();

  @override
  List<Object?> get props => [];
}

class SaveLiveSessionEvent extends WorkoutEvent {
  const SaveLiveSessionEvent({
    required this.reps,
    required this.duration,
    this.avgRepDuration,
    this.manualAdjustments = 0,
  });

  final int reps;
  final Duration duration;
  final Duration? avgRepDuration;
  final int manualAdjustments;

  @override
  List<Object?> get props => [
        reps,
        duration,
        avgRepDuration,
        manualAdjustments,
      ];
}

class DeleteSessionEvent extends WorkoutEvent {
  const DeleteSessionEvent(this.sessionId);

  final String sessionId;

  @override
  List<Object?> get props => [sessionId];
}

class UpdateSessionRepsEvent extends WorkoutEvent {
  const UpdateSessionRepsEvent({
    required this.sessionId,
    required this.reps,
  });

  final String sessionId;
  final int reps;

  @override
  List<Object?> get props => [sessionId, reps];
}

class UpdatePreferencesEvent extends WorkoutEvent {
  const UpdatePreferencesEvent(this.preferences);

  final WorkoutPreferences preferences;

  @override
  List<Object?> get props => [preferences];
}

class SyncWorkoutDataEvent extends WorkoutEvent {
  const SyncWorkoutDataEvent();

  @override
  List<Object?> get props => [];
}

class ResetWorkoutDataEvent extends WorkoutEvent {
  const ResetWorkoutDataEvent();

  @override
  List<Object?> get props => [];
}
