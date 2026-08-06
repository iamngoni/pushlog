import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';
import 'package:pushlog/today/views/widgets/friends_leaderboard.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({required this.onTabChanged, super.key});

  final ValueChanged<PushlogTab> onTabChanged;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  LeaderboardPeriod _period = LeaderboardPeriod.today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final authState = context.watch<AuthCubit>().state;
    final workoutState = context.watch<WorkoutBloc>().state;
    if (authState is! AuthAuthenticated || workoutState is! WorkoutLoaded) {
      return const SizedBox.shrink();
    }

    final me = authState.profile;
    return ColoredBox(
      color: theme.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: theme.accentInk,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xxl,
              AppSpacing.gutter,
              AppSpacing.sectionLarge,
            ),
            children: [
              _Header(
                theme: theme,
                requestCount: context
                    .watch<FriendsCubit>()
                    .state
                    .incomingRequests
                    .length,
                onManage: () => unawaited(
                  showFriendManagerSheet(
                    context: context,
                    theme: theme,
                    me: me,
                    todayCount: workoutState.todayCount,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              _PeriodSwitch(
                theme: theme,
                value: _period,
                onChanged: (period) => setState(() => _period = period),
              ),
              const SizedBox(height: AppSpacing.block),
              BlocBuilder<FriendsCubit, FriendsState>(
                builder: (_, state) => _RaceHeadline(
                  theme: theme,
                  me: me,
                  entries: state.leaderboard,
                  period: _period,
                  todayCount: workoutState.todayCount,
                  weekCount: workoutState.weekCount,
                  totalAllTime: workoutState.totalAllTime,
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              FriendsLeaderboard(
                theme: theme,
                me: me,
                todayCount: workoutState.todayCount,
                weekCount: workoutState.weekCount,
                totalAllTime: workoutState.totalAllTime,
                period: _period,
                showHeader: false,
              ),
              const SizedBox(height: AppSpacing.block),
              Divider(color: theme.divider),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: theme.secondaryInk,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(
                      'Only accepted friends can see your scores. '
                      'Lead-change alerts are sent to both competitors.',
                      style: AppTypography.body(color: theme.secondaryInk),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final authState = context.read<AuthCubit>().state;
    final workoutState = context.read<WorkoutBloc>().state;
    if (authState is! AuthAuthenticated || workoutState is! WorkoutLoaded) {
      return;
    }
    await context.read<FriendsCubit>().load(
      me: authState.profile,
      todayCount: workoutState.todayCount,
      weekCount: workoutState.weekCount,
      totalAllTime: workoutState.totalAllTime,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.requestCount,
    required this.onManage,
  });

  final AppTheme theme;
  final int requestCount;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PUSHLOG',
                style: AppTypography.overline(color: theme.tertiaryInk),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Friends',
                style: AppTypography.headingLarge(color: theme.ink),
              ),
            ],
          ),
        ),
        Badge(
          isLabelVisible: requestCount > 0,
          label: Text('$requestCount'),
          backgroundColor: theme.accent,
          textColor: AppColors.fixedDark,
          child: IconButton.filledTonal(
            onPressed: onManage,
            tooltip: 'Manage friends',
            style: IconButton.styleFrom(
              backgroundColor: theme.surface,
              foregroundColor: theme.ink,
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ),
      ],
    );
  }
}

class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  final AppTheme theme;
  final LeaderboardPeriod value;
  final ValueChanged<LeaderboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.divider),
      ),
      child: Row(
        children: [
          _item('Today', LeaderboardPeriod.today),
          _item('This week', LeaderboardPeriod.week),
          _item('All time', LeaderboardPeriod.allTime),
        ],
      ),
    );
  }

  Widget _item(String label, LeaderboardPeriod period) {
    final selected = value == period;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onChanged(period),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? theme.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? theme.background : theme.secondaryInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RaceHeadline extends StatelessWidget {
  const _RaceHeadline({
    required this.theme,
    required this.me,
    required this.entries,
    required this.period,
    required this.todayCount,
    required this.weekCount,
    required this.totalAllTime,
  });

  final AppTheme theme;
  final UserProfile me;
  final List<FriendProfile> entries;
  final LeaderboardPeriod period;
  final int todayCount;
  final int weekCount;
  final int totalAllTime;

  @override
  Widget build(BuildContext context) {
    final ranked = entries
        .map(
          (entry) => entry.uid == me.uid
              ? entry.copyWith(
                  todayCount: todayCount,
                  weekCount: weekCount,
                  totalAllTime: totalAllTime,
                )
              : entry,
        )
        .toList();
    if (!ranked.any((entry) => entry.uid == me.uid)) {
      ranked.add(
        FriendProfile.fromUserProfile(
          me,
          isMe: true,
          todayCount: todayCount,
          weekCount: weekCount,
          totalAllTime: totalAllTime,
        ),
      );
    }
    ranked.sort(
      (left, right) => right.scoreFor(period).compareTo(left.scoreFor(period)),
    );
    final myRank = ranked.indexWhere((entry) => entry.uid == me.uid);
    final myScore = ranked[myRank].scoreFor(period);
    final hasRivals = ranked.length > 1;
    final leading = myRank == 0;
    final comparison = leading && hasRivals ? ranked[1] : ranked.first;
    final gap = (myScore - comparison.scoreFor(period)).abs();

    final title = !hasRivals
        ? 'Bring a friend into the race.'
        : leading
        ? gap == 0
              ? 'The lead is tied.'
              : 'You lead by $gap.'
        : '$gap reps to catch @${ranked.first.username}.';
    final detail = !hasRivals
        ? 'Your score is ready. Add someone worth chasing.'
        : leading
        ? 'Keep moving. Your friends get an alert when you pass them.'
        : 'Log the next set and the board updates for everyone.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: theme.ink,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              hasRivals ? '#${myRank + 1}' : '—',
              style: const TextStyle(
                color: AppColors.fixedDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.title(color: theme.background),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail,
                  style: AppTypography.body(
                    color: theme.background.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
