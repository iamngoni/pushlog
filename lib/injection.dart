//
//  pushlog
//  injection.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pushlog/auth/services/auth_service.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/services/reminder_service.dart';
import 'package:pushlog/core/services/storage_service.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';
import 'package:pushlog/platform/health/health_service.dart';
import 'package:pushlog/platform/live_tracking/live_tracking_service.dart';
import 'package:pushlog/platform/watch/watch_service.dart';
import 'package:pushlog/workout/models/repos/abs/workout_repository.dart';
import 'package:pushlog/workout/models/repos/impl/cloud_workout_repository.dart';
import 'package:pushlog/workout/models/repos/impl/local_workout_repository.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureInjection() async {
  if (getIt.isRegistered<SharedPreferences>()) {
    await getIt.reset();
  }

  final prefs = await SharedPreferences.getInstance();
  final firebaseAuth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final googleSignIn = GoogleSignIn.instance;
  final reminderService = ReminderService();
  await reminderService.initialize();
  final storageService = StorageService(prefs);
  final localRepository = LocalWorkoutRepository(
    storage: storageService,
    scopeResolver: () => firebaseAuth.currentUser?.uid ?? 'guest',
  );
  final profileService = ProfileService(firestore);
  const healthService = HealthService();
  const liveTrackingService = LiveTrackingService();
  const watchService = WatchService();
  final authService = AuthService(
    firebaseAuth,
    googleSignIn,
  );
  final workoutRepo = CloudWorkoutRepository(
    localRepository: localRepository,
    auth: firebaseAuth,
    firestore: firestore,
    profileService: profileService,
  );

  getIt
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<FirebaseAuth>(firebaseAuth)
    ..registerSingleton<FirebaseFirestore>(firestore)
    ..registerSingleton<GoogleSignIn>(googleSignIn)
    ..registerSingleton<ReminderService>(reminderService)
    ..registerSingleton<StorageService>(storageService)
    ..registerSingleton<AuthService>(authService)
    ..registerSingleton<ProfileService>(profileService)
    ..registerSingleton<HealthService>(healthService)
    ..registerSingleton<LiveTrackingService>(liveTrackingService)
    ..registerSingleton<WatchService>(watchService)
    ..registerSingleton<LocalWorkoutRepository>(
      localRepository,
    )
    ..registerSingleton<WorkoutRepository>(workoutRepo)
    ..registerFactory<AuthCubit>(
      () => AuthCubit(
        authService: getIt<AuthService>(),
        profileService: getIt<ProfileService>(),
        reminderService: getIt<ReminderService>(),
      ),
    )
    ..registerFactory<FriendsCubit>(
      () => FriendsCubit(getIt<ProfileService>()),
    )
    ..registerFactory<WorkoutBloc>(
      () => WorkoutBloc(
        repository: getIt<WorkoutRepository>(),
        reminderService: getIt<ReminderService>(),
      ),
    );
}
