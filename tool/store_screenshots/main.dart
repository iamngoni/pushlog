import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/state/theme_mode_cubit.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';
import 'package:pushlog/friends/views/pages/friends_page.dart';
import 'package:pushlog/history/views/pages/history_page.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/live/services/face_tracking_service.dart';
import 'package:pushlog/live/views/live_session_page.dart';
import 'package:pushlog/platform/health/health_service.dart';
import 'package:pushlog/platform/watch/watch_service.dart';
import 'package:pushlog/today/views/pages/today_page.dart';
import 'package:pushlog/training/models/training_plan.dart';
import 'package:pushlog/training/views/training_onboarding_page.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

const _screen = String.fromEnvironment(
  'STORE_SCREEN',
  defaultValue: 'today',
);

class _MockAuthCubit extends Mock implements AuthCubit {}

class _MockWorkoutBloc extends Mock implements WorkoutBloc {}

class _MockFriendsCubit extends Mock implements FriendsCubit {}

class _MockThemeModeCubit extends Mock implements ThemeModeCubit {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.backgroundDark,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: AppColors.backgroundDark,
    ),
  );

  await getIt.reset();
  getIt
    ..registerSingleton<FaceTrackingService>(FaceTrackingService())
    ..registerSingleton<WatchService>(const WatchService())
    ..registerSingleton<HealthService>(const HealthService());

  final authCubit = _MockAuthCubit();
  final workoutBloc = _MockWorkoutBloc();
  final friendsCubit = _MockFriendsCubit();
  final themeModeCubit = _MockThemeModeCubit();

  const profile = UserProfile(
    uid: 'store-alex',
    email: 'alex@example.com',
    displayName: 'Alex Morgan',
    username: 'alexmoves',
    usernameLower: 'alexmoves',
    todayCount: 32,
    weekCount: 124,
    totalAllTime: 2840,
    bestDay: 76,
    streak: 6,
  );
  final workoutState = _storeWorkoutState();
  const friendsState = FriendsState(
    leaderboard: [
      FriendProfile(
        uid: 'store-maya',
        label: 'Maya',
        username: 'maya',
        todayCount: 44,
        weekCount: 148,
        totalAllTime: 3120,
        bestDay: 82,
        streak: 8,
      ),
      FriendProfile(
        uid: 'store-alex',
        label: 'Alex',
        username: 'alexmoves',
        todayCount: 32,
        weekCount: 124,
        totalAllTime: 2840,
        bestDay: 76,
        streak: 6,
        isMe: true,
      ),
      FriendProfile(
        uid: 'store-sam',
        label: 'Sam',
        username: 'samtrains',
        todayCount: 27,
        weekCount: 116,
        totalAllTime: 2510,
        bestDay: 70,
        streak: 5,
      ),
      FriendProfile(
        uid: 'store-jordan',
        label: 'Jordan',
        username: 'jordanpushes',
        todayCount: 18,
        weekCount: 92,
        totalAllTime: 1975,
        bestDay: 64,
        streak: 3,
      ),
    ],
  );

  when(() => authCubit.state).thenReturn(const AuthAuthenticated(profile));
  when(() => authCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => workoutBloc.state).thenReturn(workoutState);
  when(() => workoutBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => friendsCubit.state).thenReturn(friendsState);
  when(() => friendsCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => themeModeCubit.state).thenReturn(ThemeMode.dark);
  when(() => themeModeCubit.stream).thenAnswer((_) => const Stream.empty());
  when(
    () => friendsCubit.load(
      me: profile,
      todayCount: any(named: 'todayCount'),
      weekCount: any(named: 'weekCount'),
      totalAllTime: any(named: 'totalAllTime'),
    ),
  ).thenAnswer((_) async {});

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<WorkoutBloc>.value(value: workoutBloc),
        BlocProvider<FriendsCubit>.value(value: friendsCubit),
        BlocProvider<ThemeModeCubit>.value(value: themeModeCubit),
      ],
      child: const _StoreScreenshotApp(),
    ),
  );
}

WorkoutLoaded _storeWorkoutState() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final preferredWeekdays = <int>{
    today.weekday,
    (today.weekday % 7) + 1,
    ((today.weekday + 2) % 7) + 1,
    ((today.weekday + 4) % 7) + 1,
  }.toList()..sort();
  final plan = TrainingPlan(
    profile: TrainingProfile(
      goal: TrainingGoal.increaseMaximum,
      experience: TrainingExperience.regular,
      baselineSource: BaselineSource.recentResult,
      baselineMaxReps: 18,
      targetMaxReps: 40,
      durationWeeks: 12,
      sessionsPerWeek: 4,
      preferredWeekdays: preferredWeekdays,
      consistencyPreference: ConsistencyPreference.weeklyPlan,
      coachingStyle: CoachingStyle.calm,
    ),
    startDate: today.subtract(const Duration(days: 35)),
    createdAt: today.subtract(const Duration(days: 35)),
  );

  const counts = [32, 0, 41, 28, 0, 36, 24, 44, 0, 38, 30, 0, 35, 29];
  final dayTotals = <String, int>{};
  final sessions = <WorkoutSession>[];
  for (var index = 0; index < counts.length; index++) {
    final date = today.subtract(Duration(days: index));
    final reps = counts[index];
    if (reps == 0) continue;
    dayTotals[WorkoutBloc.dayKey(date)] = reps;
    sessions.add(
      WorkoutSession(
        id: 'store-session-$index',
        date: date.add(const Duration(hours: 7, minutes: 30)),
        reps: reps,
        source: index.isEven ? WorkoutSource.live : WorkoutSource.manual,
        duration: index.isEven ? Duration(minutes: 4 + index) : null,
        averageRepDuration: index.isEven
            ? const Duration(milliseconds: 2150)
            : null,
      ),
    );
  }

  return WorkoutLoaded(
    dayTotals: dayTotals,
    sessions: sessions,
    preferences: WorkoutPreferences(
      remindersEnabled: true,
      reminderHour: 7,
      reminderMinute: 30,
      streakRemindersEnabled: true,
      comebackRemindersEnabled: true,
      trainingPlan: plan,
    ),
    lastSyncedAt: now.subtract(const Duration(minutes: 2)),
  );
}

class _StoreScreenshotApp extends StatelessWidget {
  const _StoreScreenshotApp();

  @override
  Widget build(BuildContext context) {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    return MaterialApp(
      title: 'Pushlog',
      debugShowCheckedModeBanner: false,
      theme: light.toMaterialTheme(Brightness.light),
      darkTheme: dark.toMaterialTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 1.4),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _SelectedStoreScreen(),
    );
  }
}

class _SelectedStoreScreen extends StatelessWidget {
  const _SelectedStoreScreen();

  @override
  Widget build(BuildContext context) {
    return switch (_screen) {
      'history' => const _TabScreen(
        selectedTab: PushlogTab.history,
        child: HistoryPage(),
      ),
      'friends' => _TabScreen(
        selectedTab: PushlogTab.friends,
        child: FriendsPage(onTabChanged: (_) {}),
      ),
      'live' => const LiveSessionPage(),
      'onboarding' => const TrainingOnboardingPage(
        preferences: WorkoutPreferences(),
      ),
      _ => _TabScreen(
        selectedTab: PushlogTab.today,
        child: TodayPage(onTabChanged: (_) {}),
      ),
    };
  }
}

class _TabScreen extends StatelessWidget {
  const _TabScreen({required this.selectedTab, required this.child});

  final PushlogTab selectedTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: PushlogNavigationBar(
        selectedTab: selectedTab,
        onTabChanged: (_) {},
      ),
    );
  }
}
