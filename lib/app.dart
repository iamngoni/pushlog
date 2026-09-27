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
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/state/theme_mode_cubit.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/training/views/training_onboarding_page.dart';
import 'package:pushlog/weight/state/weight_cubit.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final _sentryNavigatorObserver = SentryNavigatorObserver();

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(lazy: false, create: (_) => getIt<AuthCubit>()),
        // Above the MaterialApp so the toggle can rebuild the whole tree,
        // and so every screen can reach it rather than only the one that
        // happens to own the control.
        BlocProvider<ThemeModeCubit>.value(value: getIt<ThemeModeCubit>()),
      ],
      child: BlocBuilder<ThemeModeCubit, ThemeMode>(
        builder: (context, themeMode) => MaterialApp(
          title: 'Pushlog',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light().toMaterialTheme(Brightness.light),
          darkTheme: AppTheme.dark().toMaterialTheme(Brightness.dark),
          themeMode: themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          navigatorObservers: [_sentryNavigatorObserver],
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              // Dynamic Type is honoured, with the top of the range pulled
              // in. Today's count is set at 72pt; at the largest system
              // sizes an unclamped scale pushes the logging controls off the
              // bottom of the screen, which costs more accessibility than
              // the extra few points gain.
              data: media.copyWith(
                textScaler: media.textScaler.clamp(maxScaleFactor: 1.4),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const _RootView(),
        ),
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
        BlocProvider<WeightCubit>(
          create: (_) {
            final cubit = getIt<WeightCubit>();
            unawaited(cubit.load());
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
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PUSHLOG',
                style: AppTypography.overline(color: theme.tertiaryInk),
              ),
              const Spacer(),
              Text(
                'Could not load your training',
                style: AppTypography.headingMedium(color: theme.ink),
              ),
              const SizedBox(height: AppSpacing.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.proseMaxWidth,
                ),
                child: Text(
                  message,
                  style: AppTypography.body(color: theme.secondaryInk),
                ),
              ),
              const SizedBox(height: AppSpacing.block),
              PushlogButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: () => context.read<WorkoutBloc>().add(
                  const LoadWorkoutDataEvent(),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.block),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PUSHLOG',
                    style: AppTypography.overline(color: theme.tertiaryInk),
                  ),
                  Text(
                    'LOADING',
                    style: AppTypography.overline(color: theme.tertiaryInk),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: CircularProgressIndicator(
                  color: theme.accent,
                  strokeWidth: 3,
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
