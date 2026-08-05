import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';
import 'package:pushlog/live/views/live_session_page.dart';
import 'package:pushlog/today/views/widgets/action_strip.dart';
import 'package:pushlog/today/views/widgets/day_strip_view.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final PushlogTab selectedTab;
  final ValueChanged<PushlogTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return BlocBuilder<WorkoutBloc, WorkoutState>(
      builder: (context, state) {
        if (state is WorkoutLoaded) {
          return _loaded(context, theme, state);
        }
        return ColoredBox(
          color: theme.background,
          child: Center(child: CircularProgressIndicator(color: theme.accent)),
        );
      },
    );
  }

  Widget _loaded(
    BuildContext context,
    AppTheme theme,
    WorkoutLoaded state,
  ) {
    final authState = context.watch<AuthCubit>().state;
    final profile = authState is AuthAuthenticated ? authState.profile : null;
    return ColoredBox(
      color: theme.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                children: [
                  _PageHeader(theme: theme, profile: profile),
                  const SizedBox(height: 28),
                  Text(
                    'Today',
                    style: AppTypography.headingLarge(color: theme.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _longDate(DateTime.now()),
                    style: AppTypography.bodyLarge(color: theme.secondaryInk),
                  ),
                  const SizedBox(height: 24),
                  _DailyScore(theme: theme, state: state),
                  const SizedBox(height: 14),
                  _StartSessionButton(
                    theme: theme,
                    onPressed: () => _openLiveSession(context),
                  ),
                  const SizedBox(height: 30),
                  if (profile != null)
                    _TodayRace(
                      theme: theme,
                      me: profile,
                      todayCount: state.todayCount,
                      onOpenFriends: () => onTabChanged(PushlogTab.friends),
                    ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Text(
                        'Your week',
                        style: AppTypography.title(color: theme.ink),
                      ),
                      const Spacer(),
                      Text(
                        '${state.weekCount} reps',
                        style: AppTypography.body(color: theme.secondaryInk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DayStripView(summary: state.weekSummary, theme: theme),
                  const SizedBox(height: 30),
                  _LifetimeRow(theme: theme, state: state),
                ],
              ),
            ),
            if (state.pendingUndo != null)
              _UndoBar(
                theme: theme,
                reps: state.pendingUndo!.reps,
                onUndo: () => context.read<WorkoutBloc>().add(
                  const UndoLastEntryEvent(),
                ),
              ),
            ActionStrip(
              theme: theme,
              suggestedSet: state.todayPlan?.isTrainingDay ?? false
                  ? state.todayPlan!.repsPerSet
                  : null,
              onAddReps: (reps) =>
                  context.read<WorkoutBloc>().add(AddManualRepsEvent(reps)),
              onLive: () => _openLiveSession(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openLiveSession(BuildContext context) {
    final workoutBloc = context.read<WorkoutBloc>();
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider.value(
            value: workoutBloc,
            child: const LiveSessionPage(),
          ),
          fullscreenDialog: true,
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.theme, required this.profile});

  final AppTheme theme;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'PUSHLOG',
          style: AppTypography.labelMono(
            size: 11,
            color: theme.secondaryInk,
            weight: FontWeight.w700,
            letterSpacing: 2.4,
          ),
        ),
        const Spacer(),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: theme.divider),
          ),
          child: Text(
            profile?.initials ?? 'P',
            style: TextStyle(
              color: theme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyScore extends StatelessWidget {
  const _DailyScore({required this.theme, required this.state});

  final AppTheme theme;
  final WorkoutLoaded state;

  @override
  Widget build(BuildContext context) {
    final plan = state.todayPlan;
    final target = plan?.isTrainingDay ?? false ? plan!.totalReps : null;
    final progress = target == null || target == 0
        ? 0.0
        : (state.todayCount / target).clamp(0.0, 1.0);
    final complete = target != null && state.todayCount >= target;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: theme.accent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  complete ? 'PLAN COMPLETE' : 'REPS TODAY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMono(
                    size: 11,
                    color: AppColors.fixedDark.withAlpha(180),
                    weight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (target != null)
                Text(
                  '${state.todayCount} / $target',
                  style: const TextStyle(
                    color: AppColors.fixedDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  '${state.todayCount}',
                  key: ValueKey(state.todayCount),
                  style: AppTypography.displayLarge(color: AppColors.fixedDark),
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(bottom: 7),
                child: Text(
                  'reps',
                  style: TextStyle(
                    color: AppColors.fixedDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (target != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                color: AppColors.fixedDark,
                backgroundColor: AppColors.fixedDark.withAlpha(35),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              complete
                  ? 'Done for today. Extra reps still count.'
                  : '${plan!.sets} sets × ${plan.repsPerSet} reps on your plan',
              style: TextStyle(
                color: AppColors.fixedDark.withAlpha(190),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else
            Text(
              'Recovery day. Move if you want to—nothing to make up.',
              style: TextStyle(
                color: AppColors.fixedDark.withAlpha(190),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _StartSessionButton extends StatelessWidget {
  const _StartSessionButton({required this.theme, required this.onPressed});

  final AppTheme theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start a counted session'),
        style: FilledButton.styleFrom(
          backgroundColor: theme.ink,
          foregroundColor: theme.background,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _TodayRace extends StatelessWidget {
  const _TodayRace({
    required this.theme,
    required this.me,
    required this.todayCount,
    required this.onOpenFriends,
  });

  final AppTheme theme;
  final UserProfile me;
  final int todayCount;
  final VoidCallback onOpenFriends;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FriendsCubit, FriendsState>(
      builder: (_, state) {
        final entries = state.leaderboard
            .map(
              (entry) => entry.uid == me.uid
                  ? entry.copyWith(todayCount: todayCount)
                  : entry,
            )
            .toList();
        if (!entries.any((entry) => entry.uid == me.uid)) {
          entries.add(
            FriendProfile.fromUserProfile(
              me,
              isMe: true,
              todayCount: todayCount,
            ),
          );
        }
        entries.sort((a, b) => b.todayCount.compareTo(a.todayCount));
        final myRank = entries.indexWhere((entry) => entry.uid == me.uid);
        final hasFriends = entries.length > 1;
        final title = !hasFriends
            ? 'Add a friend to start a race'
            : myRank == 0
            ? 'You’re leading today'
            : '${entries.first.todayCount - todayCount} reps behind '
                  '@${entries.first.username}';
        final detail = !hasFriends
            ? 'Daily, weekly, and all-time boards live here.'
            : '#${myRank + 1} of ${entries.length} · updates after every set';

        return InkWell(
          onTap: onOpenFriends,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: AppColors.fixedDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.title(color: theme.ink)),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: AppTypography.body(color: theme.secondaryInk),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.secondaryInk),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LifetimeRow extends StatelessWidget {
  const _LifetimeRow({required this.theme, required this.state});

  final AppTheme theme;
  final WorkoutLoaded state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.divider),
          bottom: BorderSide(color: theme.divider),
        ),
      ),
      child: Row(
        children: [
          _stat('All time', '${state.totalAllTime}'),
          _divider(),
          _stat('Best day', '${state.bestDay}'),
          _divider(),
          _stat('Streak', '${state.streak}d'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTypography.headingMedium(color: theme.ink)),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.body(color: theme.secondaryInk)),
      ],
    ),
  );

  Widget _divider() => Container(
    width: 1,
    height: 42,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: theme.divider,
  );
}

class _UndoBar extends StatelessWidget {
  const _UndoBar({
    required this.theme,
    required this.reps,
    required this.onUndo,
  });

  final AppTheme theme;
  final int reps;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
      color: theme.ink,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '+$reps reps logged',
              style: TextStyle(
                color: theme.background,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(foregroundColor: theme.accent),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
  }
}

String _longDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}
