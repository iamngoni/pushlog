//
//  pushlog
//  today_page.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/core/views/widgets/tap_surface.dart';
import 'package:pushlog/live/views/live_session_page.dart';
import 'package:pushlog/today/views/widgets/action_strip.dart';
import 'package:pushlog/today/views/widgets/count_block.dart';
import 'package:pushlog/today/views/widgets/day_strip_view.dart';
import 'package:pushlog/today/views/widgets/friends_leaderboard.dart';
import 'package:pushlog/today/views/widgets/stats_block.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final PushlogTab selectedTab;
  final void Function(PushlogTab) onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return BlocBuilder<WorkoutBloc, WorkoutState>(
      builder: (context, state) {
        if (state is WorkoutLoaded) {
          return buildLoaded(context, theme, state);
        }
        if (state is WorkoutLoading) {
          return buildLoading(theme);
        }
        return buildInitial(theme);
      },
    );
  }

  Widget buildLoaded(
    BuildContext context,
    AppTheme theme,
    WorkoutLoaded state,
  ) {
    final authState = context.watch<AuthCubit>().state;
    final profile = authState is AuthAuthenticated ? authState.profile : null;
    return ColoredBox(
      color: theme.background,
      child: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    buildHeader(theme),
                    const SizedBox(height: 18),
                    CountBlock(
                      count: state.todayCount,
                      theme: theme,
                    ),
                    const SizedBox(height: 18),
                    Divider(
                      height: 1,
                      color: theme.divider,
                    ),
                    const SizedBox(height: 14),
                    DayStripView(
                      summary: state.weekSummary,
                      theme: theme,
                    ),
                    const SizedBox(height: 20),
                    if (profile != null)
                      FriendsLeaderboard(
                        theme: theme,
                        me: profile,
                        todayCount: state.todayCount,
                      ),
                    const Spacer(),
                    StatsBlock(
                      streak: state.streak,
                      bestDay: state.bestDay,
                      totalAllTime: state.totalAllTime,
                      theme: theme,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          buildBottomArea(context, theme, state),
        ],
      ),
    );
  }

  Widget buildHeader(AppTheme theme) {
    final now = DateTime.now();
    const days = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final dow = days[now.weekday - 1];
    final mon = months[now.month - 1];
    final d = now.day.toString().padLeft(2, '0');
    final dateLabel = '$dow $d $mon';

    return Row(
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
          dateLabel,
          style: AppTypography.labelMono(
            color: theme.secondaryInk,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget buildBottomArea(
    BuildContext context,
    AppTheme theme,
    WorkoutLoaded state,
  ) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          if (state.pendingUndo != null) buildUndoStrip(context, theme, state),
          ActionStrip(
            theme: theme,
            onAddReps: (reps) =>
                context.read<WorkoutBloc>().add(AddManualRepsEvent(reps)),
            onLive: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LiveSessionPage(),
                    fullscreenDialog: true,
                  ),
                ),
              );
            },
          ),
          buildBottomTabBar(theme),
        ],
      ),
    );
  }

  Widget buildUndoStrip(
    BuildContext context,
    AppTheme theme,
    WorkoutLoaded state,
  ) {
    final reps = state.pendingUndo!.reps;
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(
          top: BorderSide(color: theme.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'LAST LOG',
                    style: AppTypography.labelMono(
                      size: 8,
                      color: theme.secondaryInk,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '+$reps',
                    style: AppTypography.displayUndo(
                      color: theme.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: theme.divider,
          ),
          Expanded(
            child: TapSurface(
              onTap: () =>
                  context.read<WorkoutBloc>().add(const UndoLastEntryEvent()),
              semanticLabel: 'Undo last log',
              color: theme.accent,
              child: Center(
                child: Text(
                  'UNDO',
                  style: AppTypography.displayUndo(
                    color: AppColors.fixedDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomTabBar(AppTheme theme) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(
          top: BorderSide(color: theme.divider),
        ),
      ),
      child: Row(
        children: [
          buildTabButton('TODAY', PushlogTab.today, theme),
          buildTabButton(
            'HISTORY',
            PushlogTab.history,
            theme,
          ),
          buildTabButton(
            'SETTINGS',
            PushlogTab.settings,
            theme,
          ),
        ],
      ),
    );
  }

  Widget buildTabButton(
    String title,
    PushlogTab tab,
    AppTheme theme,
  ) {
    final isSelected = selectedTab == tab;
    return Expanded(
      child: TapSurface(
        onTap: () => onTabChanged(tab),
        selected: isSelected,
        child: Center(
          child: Text(
            title,
            style: AppTypography.labelMono(
              color: isSelected ? theme.ink : theme.secondaryInk,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLoading(AppTheme theme) {
    return ColoredBox(
      color: theme.background,
      child: Center(
        child: CircularProgressIndicator(
          color: theme.accent,
        ),
      ),
    );
  }

  Widget buildInitial(AppTheme theme) {
    return ColoredBox(color: theme.background);
  }
}
