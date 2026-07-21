import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/platform/health/health_service.dart';
import 'package:pushlog/platform/live_tracking/live_tracking_service.dart';
import 'package:pushlog/platform/watch/watch_service.dart';
import 'package:pushlog/today/views/pages/today_page.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class _MockAuthCubit extends Mock implements AuthCubit {}

class _MockWorkoutBloc extends Mock implements WorkoutBloc {}

void main() {
  late AuthCubit authCubit;
  late WorkoutBloc workoutBloc;

  final loadedState = WorkoutLoaded(
    dayTotals: {
      WorkoutBloc.dayKey(DateTime.now()): 12,
    },
    sessions: const [],
    preferences: const WorkoutPreferences(),
  );

  setUp(() async {
    await getIt.reset();
    getIt
      ..registerSingleton<LiveTrackingService>(const LiveTrackingService())
      ..registerSingleton<WatchService>(const WatchService())
      ..registerSingleton<HealthService>(const HealthService());

    authCubit = _MockAuthCubit();
    workoutBloc = _MockWorkoutBloc();
    when(() => authCubit.state).thenReturn(const AuthSignedOut());
    when(
      () => authCubit.stream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
    when(() => workoutBloc.state).thenReturn(loadedState);
    when(
      () => workoutBloc.stream,
    ).thenAnswer((_) => Stream<WorkoutState>.value(loadedState));
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('live action opens live session route with workout context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<WorkoutBloc>.value(value: workoutBloc),
          ],
          child: TodayPage(
            selectedTab: PushlogTab.today,
            onTabChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('LIVE'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('GUIDED LIVE'), findsOneWidget);
    expect(
      find.text('TIMED SESSION MODE. START HERE, COUNT CLEAN, SAVE ONCE.'),
      findsOneWidget,
    );
  });
}
