import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/services/app_info_service.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/platform/health/health_service.dart';
import 'package:pushlog/settings/views/pages/settings_page.dart';
import 'package:pushlog/weight/state/weight_cubit.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

import '../../../weight/support/memory_weight_repository.dart';

class _MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

class _MockWorkoutBloc extends MockBloc<WorkoutEvent, WorkoutState>
    implements WorkoutBloc {}

void main() {
  late AuthCubit authCubit;
  late WorkoutBloc workoutBloc;

  const loadedState = WorkoutLoaded(
    dayTotals: {},
    sessions: [],
    preferences: WorkoutPreferences(
      remindersEnabled: true,
      reminderHour: 6,
      reminderMinute: 45,
    ),
  );

  setUp(() async {
    await getIt.reset();
    getIt
      ..registerSingleton<HealthService>(const HealthService())
      ..registerSingleton<AppInfoService>(
        AppInfoService(
          packageInfoLoader: () async => PackageInfo(
            appName: 'Pushlog',
            packageName: 'za.co.codecraftsolutions.pushlog',
            version: '1.1.0',
            buildNumber: '25',
          ),
        ),
      );

    authCubit = _MockAuthCubit();
    workoutBloc = _MockWorkoutBloc();
    whenListen(
      authCubit,
      const Stream<AuthState>.empty(),
      initialState: const AuthSignedOut(),
    );
    whenListen(
      workoutBloc,
      const Stream<WorkoutState>.empty(),
      initialState: loadedState,
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('reminder time is an accessible button that opens the picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1800);
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
            BlocProvider<WeightCubit>(
              create: (_) => WeightCubit(MemoryWeightRepository()),
            ),
          ],
          child: const Scaffold(body: SettingsPage()),
        ),
      ),
    );
    await tester.pump();

    final reminderTime = find.bySemanticsLabel(
      'Change reminder time, current 06:45',
    );
    expect(reminderTime, findsOneWidget);

    await tester.tap(reminderTime);
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
  });
}
