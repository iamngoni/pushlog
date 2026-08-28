import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/live/services/face_tracking_service.dart';
import 'package:pushlog/live/views/live_session_page.dart';
import 'package:pushlog/platform/health/health_service.dart';
import 'package:pushlog/platform/watch/watch_service.dart';
import 'package:pushlog/platform/watch/watch_state.dart';
import 'package:pushlog/today/views/pages/today_page.dart';
import 'package:pushlog/training/models/training_plan.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class _MockAuthCubit extends Mock implements AuthCubit {}

class _MockWorkoutBloc extends Mock implements WorkoutBloc {}

class _MockFriendsCubit extends Mock implements FriendsCubit {}

class _ReadyFaceTrackingService extends FaceTrackingService {
  @override
  Future<FaceTrackingSnapshot> start() async => const FaceTrackingSnapshot(
    phase: FaceTrackingPhase.ready,
  );
}

class _PhoneOnlyWatchService extends WatchService {
  const _PhoneOnlyWatchService();

  @override
  Future<WatchStatus> status() async => const WatchStatus.unsupported();

  @override
  Future<WatchStatus> beginLiveWorkout({
    required String sessionId,
    required DateTime startedAt,
    required bool preferWatch,
  }) async => const WatchStatus.unsupported();

  @override
  Future<HealthKitWriteOwner> stopLiveWorkout({
    required String sessionId,
    required int reps,
    required Duration duration,
    required DateTime endedAt,
  }) async => HealthKitWriteOwner.phone;
}

class _ReadyWatchService extends WatchService {
  bool? preferWatch;

  @override
  Future<WatchStatus> status() async => const WatchStatus(
    isSupported: true,
    isPaired: true,
    isAppInstalled: true,
    isReachable: true,
    statusLabel: 'WATCH READY',
  );

  @override
  Stream<WatchStatus> statuses() => const Stream<WatchStatus>.empty();

  @override
  Future<WatchStatus> beginLiveWorkout({
    required String sessionId,
    required DateTime startedAt,
    required bool preferWatch,
  }) async {
    this.preferWatch = preferWatch;
    return const WatchStatus(
      isSupported: true,
      isPaired: true,
      isAppInstalled: true,
      isReachable: true,
      statusLabel: 'WATCH RECORDING',
    );
  }
}

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
      ..registerSingleton<FaceTrackingService>(FaceTrackingService())
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

  testWidgets('start action opens live session route with workout context', (
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
          child: TodayPage(onTabChanged: (_) {}),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Start a counted session'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('GUIDED LIVE'), findsOneWidget);
    expect(
      find.text('Timed session mode. Start here, count clean, save once.'),
      findsOneWidget,
    );
  });

  testWidgets('counted session setup scrolls to Start on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
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
        home: BlocProvider<WorkoutBloc>.value(
          value: workoutBloc,
          child: const LiveSessionPage(),
        ),
      ),
    );
    await tester.pump();

    final start = find.text('Start');
    expect(start, findsOneWidget);
    expect(start.hitTestable(), findsNothing);

    await tester.scrollUntilVisible(
      start,
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('live-session-setup-scroll')),
        matching: find.byType(Scrollable),
      ),
    );

    expect(start.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('counted session pre-flight scrolls to Begin', (tester) async {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await getIt.unregister<FaceTrackingService>();
    getIt.registerSingleton<FaceTrackingService>(
      _ReadyFaceTrackingService(),
    );
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: BlocProvider<WorkoutBloc>.value(
          value: workoutBloc,
          child: const LiveSessionPage(),
        ),
      ),
    );
    await tester.pump();

    final setupScrollable = find.descendant(
      of: find.byKey(const ValueKey('live-session-setup-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Start'),
      300,
      scrollable: setupScrollable,
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('PRE-FLIGHT'), findsOneWidget);
    final begin = find.text('Begin');
    expect(begin, findsOneWidget);
    expect(begin.hitTestable(), findsNothing);

    await tester.scrollUntilVisible(
      begin,
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('live-session-preflight-scroll')),
        matching: find.byType(Scrollable),
      ),
    );

    expect(begin.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a live session exports it to the health bridge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await getIt.unregister<FaceTrackingService>();
    getIt.registerSingleton<FaceTrackingService>(
      _ReadyFaceTrackingService(),
    );
    await getIt.unregister<WatchService>();
    getIt.registerSingleton<WatchService>(const _PhoneOnlyWatchService());

    const healthState = WorkoutLoaded(
      dayTotals: {},
      sessions: [],
      preferences: WorkoutPreferences(healthSyncEnabled: true),
    );
    when(() => workoutBloc.state).thenReturn(healthState);
    when(
      () => workoutBloc.stream,
    ).thenAnswer((_) => Stream<WorkoutState>.value(healthState));

    const healthChannel = MethodChannel(HealthService.channelName);
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(healthChannel, (call) async {
            calls.add(call);
            return true;
          });
    addTearDown(
      () => messenger.setMockMethodCallHandler(healthChannel, null),
    );

    final theme = AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: BlocProvider<WorkoutBloc>.value(
          value: workoutBloc,
          child: const LiveSessionPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Start'),
      600,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('live-session-setup-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    final start = find.text('Start').hitTestable();
    expect(start, findsOneWidget);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('PRE-FLIGHT'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Manual'),
      600,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('live-session-preflight-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Manual').hitTestable());
    await tester.pump();
    expect(find.text('SESSION'), findsOneWidget);
    await tester.tap(find.text('+1').hitTestable());
    final end = find.text('End').hitTestable();
    expect(end, findsOneWidget);
    await tester.tap(end);
    await tester.pumpAndSettle();
    expect(find.text('SUMMARY'), findsOneWidget);
    final summaryScrollable = find.descendant(
      of: find.byKey(const ValueKey('live-session-summary-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('effort-7')),
      400,
      scrollable: summaryScrollable,
    );
    await tester.tap(find.byKey(const ValueKey('effort-7')).hitTestable());
    await tester.scrollUntilVisible(
      find.text('Save'),
      400,
      scrollable: summaryScrollable,
    );
    await tester.tap(find.text('Save').hitTestable());
    await tester.pumpAndSettle();

    final saveCall = calls.singleWhere(
      (call) => call.method == 'saveLiveSession',
    );
    final payload = Map<Object?, Object?>.from(saveCall.arguments as Map);
    expect(payload['reps'], 1);
    expect(payload['endedAtEpochMilliseconds'], isA<int>());
    expect(payload['externalId'], isNotEmpty);
    expect(payload['effortScore'], 7);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'watch selection launches tracking and shows pending health metrics',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });
      await getIt.unregister<FaceTrackingService>();
      getIt.registerSingleton<FaceTrackingService>(
        _ReadyFaceTrackingService(),
      );
      await getIt.unregister<WatchService>();
      final watchService = _ReadyWatchService();
      getIt.registerSingleton<WatchService>(watchService);

      const watchState = WorkoutLoaded(
        dayTotals: {},
        sessions: [],
        preferences: WorkoutPreferences(),
      );
      when(() => workoutBloc.state).thenReturn(watchState);
      when(
        () => workoutBloc.stream,
      ).thenAnswer((_) => const Stream<WorkoutState>.empty());

      final theme = AppTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.toMaterialTheme(Brightness.light),
          home: BlocProvider<WorkoutBloc>.value(
            value: workoutBloc,
            child: const LiveSessionPage(),
          ),
        ),
      );
      await tester.pump();

      final setupScrollable = find.descendant(
        of: find.byKey(const ValueKey('live-session-setup-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('iPhone + Apple Watch'),
        300,
        scrollable: setupScrollable,
      );
      await tester.tap(find.text('iPhone + Apple Watch').hitTestable());
      await tester.scrollUntilVisible(
        find.text('Start'),
        600,
        scrollable: setupScrollable,
      );
      await tester.tap(find.text('Start').hitTestable());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Manual'),
        600,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('live-session-preflight-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Manual').hitTestable());
      await tester.pumpAndSettle();

      expect(watchService.preferWatch, isTrue);
      expect(find.text('WATCH RECORDING'), findsOneWidget);
      expect(find.text('-- BPM'), findsOneWidget);
      expect(find.text('-- KCAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows the current plan as the primary daily target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    final now = DateTime.now();
    final plan = TrainingPlan(
      profile: TrainingProfile(
        goal: TrainingGoal.buildHabit,
        experience: TrainingExperience.newToTraining,
        baselineSource: BaselineSource.recentResult,
        baselineMaxReps: 10,
        targetMaxReps: 20,
        durationWeeks: 12,
        sessionsPerWeek: 2,
        preferredWeekdays: [now.weekday, (now.weekday % 7) + 1],
        consistencyPreference: ConsistencyPreference.weeklyPlan,
        coachingStyle: CoachingStyle.calm,
      ),
      startDate: DateTime(now.year, now.month, now.day),
      createdAt: now,
    );
    final planState = WorkoutLoaded(
      dayTotals: {WorkoutBloc.dayKey(now): 12},
      sessions: const [],
      preferences: WorkoutPreferences(trainingPlan: plan),
    );
    when(() => workoutBloc.state).thenReturn(planState);
    when(
      () => workoutBloc.stream,
    ).thenAnswer((_) => Stream<WorkoutState>.value(planState));
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<WorkoutBloc>.value(value: workoutBloc),
          ],
          child: TodayPage(onTabChanged: (_) {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TARGET COMPLETE'), findsOneWidget);
    expect(
      find.text('Done for today. Extra reps still count.'),
      findsOneWidget,
    );
    // Matched on the hero style rather than the string: the week strip
    // also renders today's count, so a bare text finder is ambiguous.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == '12' &&
            widget.style?.fontSize == 72,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not claim a lead when every friend has zero reps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    const me = UserProfile(
      uid: 'me',
      username: 'me',
      usernameLower: 'me',
    );
    const zeroState = WorkoutLoaded(
      dayTotals: {},
      sessions: [],
      preferences: WorkoutPreferences(),
    );
    final friendsCubit = _MockFriendsCubit();
    when(() => authCubit.state).thenReturn(const AuthAuthenticated(me));
    when(() => workoutBloc.state).thenReturn(zeroState);
    when(
      () => workoutBloc.stream,
    ).thenAnswer((_) => const Stream<WorkoutState>.empty());
    when(() => friendsCubit.state).thenReturn(
      const FriendsState(
        leaderboard: [
          FriendProfile(
            uid: 'me',
            label: 'me',
            username: 'me',
            todayCount: 0,
            isMe: true,
          ),
          FriendProfile(
            uid: 'friend',
            label: 'Friend',
            username: 'friend',
            todayCount: 0,
          ),
        ],
      ),
    );
    when(
      () => friendsCubit.stream,
    ).thenAnswer((_) => const Stream<FriendsState>.empty());
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<WorkoutBloc>.value(value: workoutBloc),
            BlocProvider<FriendsCubit>.value(value: friendsCubit),
          ],
          child: TodayPage(onTabChanged: (_) {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No leader yet today'), findsOneWidget);
    expect(find.text('You’re leading today'), findsNothing);
    expect(
      find.text('Everyone starts at 0 · first rep takes the lead'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
