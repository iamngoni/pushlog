//
//  pushlog
//  app.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/auth/views/sign_in_page.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/training/views/training_onboarding_page.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      lazy: false,
      create: (_) => getIt<AuthCubit>(),
      child: MaterialApp(
        title: 'Pushlog',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        darkTheme: AppTheme.dark().toMaterialTheme(Brightness.dark),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const _RootView(),
      ),
    );
  }
}

class _RootView extends StatelessWidget {
  const _RootView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthLoading() => const _LoadingScreen(),
          AuthSignedOut() => const SignInPage(),
          AuthBlocked() => AuthBlockedPage(message: state.message),
          AuthNeedsUsername() => UsernameClaimPage(state: state),
          AuthAuthenticated() => _AuthenticatedRoot(
            key: ValueKey(state.profile.uid),
            profile: state.profile,
          ),
        };
      },
    );
  }
}

class _AuthenticatedRoot extends StatelessWidget {
  const _AuthenticatedRoot({required this.profile, super.key});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<WorkoutBloc>(
          create: (_) =>
              getIt<WorkoutBloc>()..add(const LoadWorkoutDataEvent()),
        ),
        BlocProvider<FriendsCubit>(
          create: (_) {
            final cubit = getIt<FriendsCubit>();
            unawaited(cubit.load(me: profile, todayCount: profile.todayCount));
            return cubit;
          },
        ),
      ],
      child: const _TrainingGate(),
    );
  }
}

class _TrainingGate extends StatelessWidget {
  const _TrainingGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutBloc, WorkoutState>(
      builder: (context, state) {
        return switch (state) {
          WorkoutInitial() || WorkoutLoading() => const _LoadingScreen(),
          WorkoutError() => _WorkoutErrorScreen(message: state.error.message),
          WorkoutLoaded() when !state.preferences.hasCompletedOnboarding =>
            TrainingOnboardingPage(preferences: state.preferences),
          WorkoutLoaded() => const AppScaffold(),
        };
      },
    );
  }
}

class _WorkoutErrorScreen extends StatelessWidget {
  const _WorkoutErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PUSHLOG',
                style: AppTypography.labelMono(
                  color: theme.secondaryInk,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              Text(
                'Could not load your training data.',
                style: AppTypography.headingMedium(color: theme.ink),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: AppTypography.body(color: theme.secondaryInk),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () => context.read<WorkoutBloc>().add(
                    const LoadWorkoutDataEvent(),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: AppColors.fixedDark,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(
                    'TRY AGAIN',
                    style: AppTypography.labelMono(
                      color: AppColors.fixedDark,
                      letterSpacing: 1.4,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PUSHLOG',
                    style: AppTypography.labelMono(
                      color: theme.secondaryInk,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    'LOADING',
                    style: AppTypography.labelMono(
                      color: theme.secondaryInk,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Center(child: CircularProgressIndicator(color: theme.accent)),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
