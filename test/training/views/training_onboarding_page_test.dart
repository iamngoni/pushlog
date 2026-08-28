import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/training/models/training_plan.dart';
import 'package:pushlog/training/views/training_onboarding_page.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class _MockWorkoutBloc extends Mock implements WorkoutBloc {}

class _FakeWorkoutEvent extends Fake implements WorkoutEvent {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeWorkoutEvent()));

  testWidgets('creates a selectable plan from the onboarding flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final bloc = _MockWorkoutBloc();
    const initial = WorkoutLoaded(
      dayTotals: {},
      sessions: [],
      preferences: WorkoutPreferences(),
    );
    when(() => bloc.state).thenReturn(initial);
    when(() => bloc.stream).thenAnswer(
      (_) => const Stream<WorkoutState>.empty(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: BlocProvider<WorkoutBloc>.value(
          value: bloc,
          child: const TrainingOnboardingPage(
            preferences: WorkoutPreferences(),
          ),
        ),
      ),
    );

    expect(find.text('What should Pushlog help you change?'), findsOneWidget);
    for (var step = 0; step < 8; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Your starting plan'), findsOneWidget);
    await tester.tap(find.text('Start plan'));
    await tester.pump();

    final captured = verify(() => bloc.add(captureAny())).captured.single;
    expect(captured, isA<UpdatePreferencesEvent>());
    final event = captured as UpdatePreferencesEvent;
    expect(event.preferences.trainingPlan, isNotNull);
    expect(event.preferences.trainingPlan!.profile.durationWeeks, 12);
  });

  testWidgets('editing choices does not restart plan progress', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    const profile = TrainingProfile(
      goal: TrainingGoal.buildHabit,
      experience: TrainingExperience.newToTraining,
      baselineSource: BaselineSource.recentResult,
      baselineMaxReps: 5,
      targetMaxReps: 15,
      durationWeeks: 12,
      sessionsPerWeek: 2,
      preferredWeekdays: [DateTime.monday, DateTime.thursday],
      consistencyPreference: ConsistencyPreference.weeklyPlan,
      coachingStyle: CoachingStyle.calm,
    );
    final originalPlan = TrainingPlan(
      profile: profile,
      startDate: DateTime(2026, 7),
      createdAt: DateTime(2026, 7, 1, 9),
    );
    final preferences = WorkoutPreferences(trainingPlan: originalPlan);
    final bloc = _MockWorkoutBloc();
    final initial = WorkoutLoaded(
      dayTotals: const {},
      sessions: const [],
      preferences: preferences,
    );
    when(() => bloc.state).thenReturn(initial);
    when(() => bloc.stream).thenAnswer(
      (_) => const Stream<WorkoutState>.empty(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: BlocProvider<WorkoutBloc>.value(
          value: bloc,
          child: TrainingOnboardingPage(
            preferences: preferences,
            isEditing: true,
          ),
        ),
      ),
    );
    for (var step = 0; step < 8; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save plan'));
    await tester.pump();

    final captured = verify(() => bloc.add(captureAny())).captured.single;
    final updatedPlan =
        (captured as UpdatePreferencesEvent).preferences.trainingPlan!;
    expect(updatedPlan.startDate, originalPlan.startDate);
    expect(updatedPlan.createdAt, originalPlan.createdAt);
  });

  testWidgets('increasing sessions leaves training days selectable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final bloc = _MockWorkoutBloc();
    when(() => bloc.state).thenReturn(
      const WorkoutLoaded(
        dayTotals: {},
        sessions: [],
        preferences: WorkoutPreferences(),
      ),
    );
    when(() => bloc.stream).thenAnswer(
      (_) => const Stream<WorkoutState>.empty(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: BlocProvider<WorkoutBloc>.value(
          value: bloc,
          child: const TrainingOnboardingPage(
            preferences: WorkoutPreferences(),
          ),
        ),
      ),
    );

    for (var step = 0; step < 4; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(find.text('TRAINING DAYS 2/5'), findsOneWidget);

    for (final day in ['TUE', 'WED', 'FRI']) {
      await tester.tap(find.text(day));
      await tester.pumpAndSettle();
    }
    expect(find.text('TRAINING DAYS 5/5'), findsOneWidget);

    await tester.tap(find.text('FRI'));
    await tester.pumpAndSettle();
    expect(find.text('TRAINING DAYS 4/5'), findsOneWidget);

    await tester.tap(find.text('SUN'));
    await tester.pumpAndSettle();
    expect(find.text('TRAINING DAYS 5/5'), findsOneWidget);

    for (var step = 4; step < 8; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Start plan'));
    await tester.pump();

    final captured = verify(() => bloc.add(captureAny())).captured.single;
    final plan = (captured as UpdatePreferencesEvent).preferences.trainingPlan!;
    expect(plan.profile.sessionsPerWeek, 5);
    expect(plan.profile.preferredWeekdays, const [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.sunday,
    ]);
  });
}
