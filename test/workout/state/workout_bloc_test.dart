import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/core/models/data/application_error.dart';
import 'package:pushlog/core/services/reminder_service.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';
import 'package:pushlog/workout/models/repos/abs/workout_repository.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class _MockWorkoutRepository extends Mock implements WorkoutRepository {}

class _MockReminderService extends Mock implements ReminderService {}

void main() {
  late WorkoutRepository repository;
  late ReminderService reminderService;

  final today = DateTime.now();
  final todayKey = WorkoutBloc.dayKey(today);
  final syncedAt = DateTime(2026, 7, 1, 8, 30);
  final storedError = ApplicationError.storageError('disk full');

  final existingSession = WorkoutSession(
    id: 'session-1',
    date: today,
    reps: 10,
    source: WorkoutSource.manual,
  );

  WorkoutBloc buildBloc() => WorkoutBloc(
    repository: repository,
    reminderService: reminderService,
  );

  WorkoutLoaded loadedState({
    Map<String, int>? dayTotals,
    List<WorkoutSession>? sessions,
    PendingUndo? pendingUndo,
  }) => WorkoutLoaded(
    dayTotals: dayTotals ?? const {},
    sessions: sessions ?? const [],
    preferences: const WorkoutPreferences(),
    pendingUndo: pendingUndo,
  );

  void stubSaveSuccess() {
    when(() => repository.saveSnapshot(any())).thenAnswer(
      (invocation) async => right(
        (invocation.positionalArguments.first as WorkoutSnapshot).copyWith(
          lastSyncedAt: syncedAt,
        ),
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(const WorkoutSnapshot());
    registerFallbackValue(const WorkoutPreferences());
  });

  setUp(() {
    repository = _MockWorkoutRepository();
    reminderService = _MockReminderService();
    when(
      () => reminderService.syncPreferences(
        any(),
        dayTotals: any(named: 'dayTotals'),
      ),
    ).thenAnswer((_) async {});
  });

  group('LoadWorkoutDataEvent', () {
    blocTest<WorkoutBloc, WorkoutState>(
      'emits loading then loaded state built from the stored snapshot',
      build: () {
        when(() => repository.loadSnapshot()).thenAnswer(
          (_) async => right(
            WorkoutSnapshot(
              sessions: [existingSession],
              lastSyncedAt: syncedAt,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadWorkoutDataEvent()),
      expect: () => [
        const WorkoutLoading(),
        isA<WorkoutLoaded>()
            .having((s) => s.dayTotals, 'dayTotals', {todayKey: 10})
            .having((s) => s.sessions, 'sessions', [existingSession])
            .having((s) => s.lastSyncedAt, 'lastSyncedAt', syncedAt),
      ],
      verify: (_) {
        verify(
          () => reminderService.syncPreferences(
            const WorkoutPreferences(),
            dayTotals: {todayKey: 10},
          ),
        ).called(1);
      },
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'emits error when the repository fails to load',
      build: () {
        when(
          () => repository.loadSnapshot(),
        ).thenAnswer((_) async => left(storedError));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadWorkoutDataEvent()),
      expect: () => [
        const WorkoutLoading(),
        WorkoutError(storedError),
      ],
    );
  });

  group('AddManualRepsEvent', () {
    blocTest<WorkoutBloc, WorkoutState>(
      'adds a manual session, bumps today total, and arms undo',
      build: () {
        stubSaveSuccess();
        return buildBloc();
      },
      seed: loadedState,
      act: (bloc) => bloc.add(const AddManualRepsEvent(10)),
      expect: () => [
        isA<WorkoutLoaded>()
            .having(
              (s) => s.dayTotals.values.fold<int>(
                0,
                (sum, reps) => sum + reps,
              ),
              'total reps',
              10,
            )
            .having((s) => s.sessions.length, 'session count', 1)
            .having(
              (s) => s.sessions.single.source,
              'session source',
              WorkoutSource.manual,
            )
            .having((s) => s.pendingUndo?.reps, 'pending undo reps', 10),
        isA<WorkoutLoaded>()
            .having((s) => s.lastSyncedAt, 'lastSyncedAt', syncedAt)
            .having((s) => s.syncError, 'syncError', isNull),
      ],
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'ignores non-positive rep counts',
      build: buildBloc,
      seed: loadedState,
      act: (bloc) => bloc.add(const AddManualRepsEvent(0)),
      expect: () => const <WorkoutState>[],
      verify: (_) {
        verifyNever(() => repository.saveSnapshot(any()));
      },
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'surfaces a sync error when persisting fails',
      build: () {
        when(
          () => repository.saveSnapshot(any()),
        ).thenAnswer((_) async => left(storedError));
        return buildBloc();
      },
      seed: loadedState,
      act: (bloc) => bloc.add(const AddManualRepsEvent(5)),
      expect: () => [
        isA<WorkoutLoaded>().having(
          (s) => s.dayTotals.values.fold<int>(
            0,
            (sum, reps) => sum + reps,
          ),
          'total reps',
          5,
        ),
        isA<WorkoutLoaded>().having(
          (s) => s.syncError,
          'syncError',
          storedError.message,
        ),
      ],
    );
  });

  group('UndoLastEntryEvent', () {
    blocTest<WorkoutBloc, WorkoutState>(
      'removes the pending session and reverts the day total',
      build: () {
        stubSaveSuccess();
        return buildBloc();
      },
      seed: () => loadedState(
        dayTotals: {todayKey: 10},
        sessions: [existingSession],
        pendingUndo: PendingUndo(
          sessionId: existingSession.id,
          reps: existingSession.reps,
          date: existingSession.date,
        ),
      ),
      act: (bloc) => bloc.add(const UndoLastEntryEvent()),
      expect: () => [
        isA<WorkoutLoaded>()
            .having((s) => s.dayTotals, 'dayTotals', isEmpty)
            .having((s) => s.sessions, 'sessions', isEmpty)
            .having((s) => s.pendingUndo, 'pendingUndo', isNull),
        isA<WorkoutLoaded>().having(
          (s) => s.lastSyncedAt,
          'lastSyncedAt',
          syncedAt,
        ),
      ],
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'does nothing when there is no pending undo',
      build: buildBloc,
      seed: () => loadedState(
        dayTotals: {todayKey: 10},
        sessions: [existingSession],
      ),
      act: (bloc) => bloc.add(const UndoLastEntryEvent()),
      expect: () => const <WorkoutState>[],
      verify: (_) {
        verifyNever(() => repository.saveSnapshot(any()));
      },
    );
  });

  group('SaveLiveSessionEvent', () {
    blocTest<WorkoutBloc, WorkoutState>(
      'adds a live session and clears any pending undo',
      build: () {
        stubSaveSuccess();
        return buildBloc();
      },
      seed: () => loadedState(
        dayTotals: {todayKey: 10},
        sessions: [existingSession],
        pendingUndo: PendingUndo(
          sessionId: existingSession.id,
          reps: existingSession.reps,
          date: existingSession.date,
        ),
      ),
      act: (bloc) => bloc.add(
        const SaveLiveSessionEvent(
          reps: 25,
          duration: Duration(minutes: 3),
          sessionId: 'live-1',
          avgRepDuration: Duration(seconds: 7),
          manualAdjustments: 2,
          effortScore: 8,
          latestHeartRate: 142.5,
          activeCalories: 18.75,
        ),
      ),
      expect: () => [
        isA<WorkoutLoaded>()
            .having(
              (s) => s.dayTotals.values.fold<int>(
                0,
                (sum, reps) => sum + reps,
              ),
              'total reps',
              35,
            )
            .having((s) => s.sessions.length, 'session count', 2)
            .having(
              (s) => s.sessions.map((session) => session.id),
              'session ids',
              contains('live-1'),
            )
            .having(
              (s) => s.sessions
                  .firstWhere(
                    (session) => session.id == 'live-1',
                  )
                  .averageRepDuration,
              'average rep duration',
              const Duration(seconds: 7),
            )
            .having(
              (s) => s.sessions
                  .firstWhere(
                    (session) => session.id == 'live-1',
                  )
                  .manualAdjustments,
              'manual adjustments',
              2,
            )
            .having(
              (s) => s.sessions
                  .firstWhere(
                    (session) => session.id == 'live-1',
                  )
                  .effortScore,
              'effort score',
              8,
            )
            .having(
              (s) => s.sessions
                  .firstWhere(
                    (session) => session.id == 'live-1',
                  )
                  .latestHeartRate,
              'latest heart rate',
              142.5,
            )
            .having(
              (s) => s.sessions
                  .firstWhere(
                    (session) => session.id == 'live-1',
                  )
                  .activeCalories,
              'active calories',
              18.75,
            )
            .having((s) => s.pendingUndo, 'pendingUndo', isNull),
        isA<WorkoutLoaded>().having(
          (s) => s.lastSyncedAt,
          'lastSyncedAt',
          syncedAt,
        ),
      ],
    );
  });

  group('DeleteSessionEvent', () {
    blocTest<WorkoutBloc, WorkoutState>(
      'removes the session and its reps from the day total',
      build: () {
        stubSaveSuccess();
        return buildBloc();
      },
      seed: () => loadedState(
        dayTotals: {todayKey: 10},
        sessions: [existingSession],
      ),
      act: (bloc) => bloc.add(DeleteSessionEvent(existingSession.id)),
      expect: () => [
        isA<WorkoutLoaded>()
            .having((s) => s.dayTotals, 'dayTotals', isEmpty)
            .having((s) => s.sessions, 'sessions', isEmpty),
        isA<WorkoutLoaded>().having(
          (s) => s.lastSyncedAt,
          'lastSyncedAt',
          syncedAt,
        ),
      ],
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'ignores unknown session ids',
      build: buildBloc,
      seed: () => loadedState(
        dayTotals: {todayKey: 10},
        sessions: [existingSession],
      ),
      act: (bloc) => bloc.add(const DeleteSessionEvent('missing')),
      expect: () => const <WorkoutState>[],
    );
  });

  group('UpdateSessionRepsEvent', () {
    blocTest<WorkoutBloc, WorkoutState>(
      'applies the rep delta to the session and day total',
      build: () {
        stubSaveSuccess();
        return buildBloc();
      },
      seed: () => loadedState(
        dayTotals: {todayKey: 10},
        sessions: [existingSession],
      ),
      act: (bloc) => bloc.add(
        UpdateSessionRepsEvent(sessionId: existingSession.id, reps: 14),
      ),
      expect: () => [
        isA<WorkoutLoaded>()
            .having((s) => s.dayTotals[todayKey], 'today total', 14)
            .having((s) => s.sessions.single.reps, 'session reps', 14),
        isA<WorkoutLoaded>().having(
          (s) => s.lastSyncedAt,
          'lastSyncedAt',
          syncedAt,
        ),
      ],
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'deletes the session when reps drop to zero',
      build: () {
        stubSaveSuccess();
        return buildBloc();
      },
      seed: () => loadedState(
        dayTotals: {todayKey: 10},
        sessions: [existingSession],
      ),
      act: (bloc) => bloc.add(
        UpdateSessionRepsEvent(sessionId: existingSession.id, reps: 0),
      ),
      expect: () => [
        isA<WorkoutLoaded>()
            .having((s) => s.dayTotals, 'dayTotals', isEmpty)
            .having((s) => s.sessions, 'sessions', isEmpty),
        isA<WorkoutLoaded>().having(
          (s) => s.lastSyncedAt,
          'lastSyncedAt',
          syncedAt,
        ),
      ],
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'does nothing when the rep count is unchanged',
      build: buildBloc,
      seed: () => loadedState(
        dayTotals: {todayKey: 10},
        sessions: [existingSession],
      ),
      act: (bloc) => bloc.add(
        UpdateSessionRepsEvent(
          sessionId: existingSession.id,
          reps: existingSession.reps,
        ),
      ),
      expect: () => const <WorkoutState>[],
    );
  });

  group('UpdatePreferencesEvent', () {
    const updatedPreferences = WorkoutPreferences(
      reminderHour: 6,
      reminderMinute: 45,
    );

    blocTest<WorkoutBloc, WorkoutState>(
      'stores the new preferences and reschedules reminders',
      build: () {
        stubSaveSuccess();
        return buildBloc();
      },
      seed: loadedState,
      act: (bloc) => bloc.add(
        const UpdatePreferencesEvent(updatedPreferences),
      ),
      expect: () => [
        isA<WorkoutLoaded>().having(
          (s) => s.preferences,
          'preferences',
          updatedPreferences,
        ),
        isA<WorkoutLoaded>().having(
          (s) => s.lastSyncedAt,
          'lastSyncedAt',
          syncedAt,
        ),
      ],
      verify: (_) {
        final reminderSync = verify(
          () => reminderService.syncPreferences(
            updatedPreferences,
            dayTotals: captureAny(named: 'dayTotals'),
          ),
        )..called(1);
        expect(reminderSync.captured.single, isEmpty);
      },
    );
  });

  group('ResetWorkoutDataEvent', () {
    blocTest<WorkoutBloc, WorkoutState>(
      'emits loading then the empty snapshot state',
      build: () {
        when(
          () => repository.resetSnapshot(),
        ).thenAnswer((_) async => right(const WorkoutSnapshot()));
        return buildBloc();
      },
      seed: () => loadedState(
        dayTotals: {todayKey: 10},
        sessions: [existingSession],
      ),
      act: (bloc) => bloc.add(const ResetWorkoutDataEvent()),
      expect: () => [
        const WorkoutLoading(),
        isA<WorkoutLoaded>()
            .having((s) => s.dayTotals, 'dayTotals', isEmpty)
            .having((s) => s.sessions, 'sessions', isEmpty),
      ],
    );
  });
}
