import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/core/views/widgets/avatar_badge.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';
import 'package:pushlog/core/views/widgets/pushlog_surface.dart';
import 'package:pushlog/core/views/widgets/pushlog_toast.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';
import 'package:pushlog/live/views/live_session_page.dart';
import 'package:pushlog/today/views/widgets/action_strip.dart';
import 'package:pushlog/today/views/widgets/day_strip_view.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({required this.onTabChanged, super.key});

  final ValueChanged<PushlogTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return BlocConsumer<WorkoutBloc, WorkoutState>(
      // Fires only when a *new* entry lands, so an undo or an unrelated
      // state change never re-announces work the user already saw.
      listenWhen: (previous, current) {
        if (previous is! WorkoutLoaded || current is! WorkoutLoaded) {
          return false;
        }
        final incoming = current.pendingUndo?.sessionId;
        return incoming != null && incoming != previous.pendingUndo?.sessionId;
      },
      listener: (context, state) {
        if (state is WorkoutLoaded) _announceLog(context, state);
      },
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

  /// Confirms a logged set and offers the way back out of it.
  ///
  /// This used to be a bar pinned above the action strip. Because nothing
  /// ever cleared it, the bar stayed on screen for the rest of the day —
  /// permanent chrome announcing something that happened hours ago. A
  /// confirmation is news for a few seconds and then it is clutter, so it
  /// now arrives as a toast carrying the undo and leaves on its own.
  void _announceLog(BuildContext context, WorkoutLoaded current) {
    final undo = current.pendingUndo;
    if (undo == null) return;

    final plan = current.todayPlan;
    final target = (plan?.isTrainingDay ?? false) ? plan!.totalReps : null;
    final complete = target != null && current.todayCount >= target;

    if (complete) {
      PushlogToast.success(
        context,
        "Today's target is done",
        detail: '${current.todayCount} reps logged. Extra reps still count.',
        actionLabel: 'Undo',
        onAction: () =>
            context.read<WorkoutBloc>().add(const UndoLastEntryEvent()),
      );
      return;
    }

    PushlogToast.success(
      context,
      '+${undo.reps} reps logged',
      detail: target == null
          ? '${current.todayCount} today'
          : '${target - current.todayCount} to go today',
      actionLabel: 'Undo',
      onAction: () =>
          context.read<WorkoutBloc>().add(const UndoLastEntryEvent()),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                  AppSpacing.gutter,
                  AppSpacing.block,
                ),
                children: [
                  _TodayHeader(theme: theme, profile: profile),
                  const SizedBox(height: AppSpacing.section),
                  _TodayHero(theme: theme, state: state),
                  const SizedBox(height: AppSpacing.xl),
                  PushlogButton(
                    label: 'Start a counted session',
                    icon: Icons.play_arrow_rounded,
                    variant: PushlogButtonVariant.secondary,
                    onPressed: () => _openLiveSession(context),
                  ),
                  const SizedBox(height: AppSpacing.sectionLarge),
                  if (profile != null) ...[
                    _RacePreview(
                      me: profile,
                      todayCount: state.todayCount,
                      onOpenFriends: () => onTabChanged(PushlogTab.friends),
                    ),
                    const SizedBox(height: AppSpacing.sectionLarge),
                  ],
                  SectionHeader(
                    title: 'Your week',
                    trailing: '${state.weekCount} reps',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  DayStripView(summary: state.weekSummary, theme: theme),
                  const SizedBox(height: AppSpacing.sectionLarge),
                  _LifetimeStats(theme: theme, state: state),
                ],
              ),
            ),
            ActionStrip(
              theme: theme,
              suggestedSet: (state.todayPlan?.isTrainingDay ?? false)
                  ? state.todayPlan!.repsPerSet
                  : null,
              onAddReps: (reps) =>
                  context.read<WorkoutBloc>().add(AddManualRepsEvent(reps)),
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

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.theme, required this.profile});

  final AppTheme theme;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'PUSHLOG',
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
        const Spacer(),
        AvatarBadge(
          initials: profile?.initials ?? 'P',
          seed: profile?.uid,
          size: 36,
        ),
      ],
    );
  }
}

/// Today's count, target, and progress.
///
/// The block is deliberately unstyled while the target is outstanding — the
/// figure carries itself at 72pt, and a Signal Lime slab behind it would
/// spend the accent on decoration. Filling the whole screen with the accent
/// colour also forces every label on top of it to be dark-on-lime, which is
/// what pushed the old version into translucent black text that read as
/// disabled.
///
/// When the target is met the block *becomes* lime. The accent then means
/// something specific and earned, and the change is the reward.
class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.theme, required this.state});

  final AppTheme theme;
  final WorkoutLoaded state;

  @override
  Widget build(BuildContext context) {
    final plan = state.todayPlan;
    final isTrainingDay = plan?.isTrainingDay ?? false;
    final target = isTrainingDay ? plan!.totalReps : null;
    final complete = target != null && state.todayCount >= target;
    final progress = target == null || target == 0
        ? 0.0
        : (state.todayCount / target).clamp(0.0, 1.0);

    final ink = complete ? theme.onAccent : theme.ink;
    final subInk = complete ? theme.onAccentMuted : theme.secondaryInk;

    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.slow),
      curve: AppMotion.settle,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.block,
      ),
      decoration: BoxDecoration(
        color: complete ? theme.accent : theme.surface,
        borderRadius: AppRadius.all(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  complete ? 'TARGET COMPLETE' : 'TODAY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.overline(color: subInk),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                style: AppTypography.labelSmall(color: subInk),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // Baseline alignment, not centring. "reps" is less than a third
          // the size of the count; centring the two would leave their
          // baselines visibly apart on a row this tall.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.base),
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                child: Text(
                  '${state.todayCount}',
                  key: ValueKey<int>(state.todayCount),
                  style: AppTypography.metricHero(color: ink),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'reps',
                style: AppTypography.headingSmall(color: subInk),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (target != null) ...[
            _ProgressTrack(
              value: progress,
              fill: complete ? theme.onAccent : theme.accent,
              track: complete
                  ? theme.onAccent.withValues(alpha: 0.24)
                  : theme.surfaceSunken,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    complete
                        ? 'Done for today. Extra reps still count.'
                        : '${target - state.todayCount} to go',
                    style: AppTypography.body(
                      color: subInk,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(
                  '${plan!.sets} × ${plan.repsPerSet}',
                  style: AppTypography.metricInline(color: subInk),
                ),
              ],
            ),
          ] else
            Text(
              'Recovery day. Move if you want to — nothing to make up.',
              style: AppTypography.body(
                color: subInk,
                weight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.value,
    required this.fill,
    required this.track,
  });

  final double value;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.all(AppRadius.indicator),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value),
        duration: AppMotion.duration(context, AppMotion.slow),
        curve: AppMotion.standard,
        builder: (context, animated, _) => LinearProgressIndicator(
          minHeight: 8,
          value: animated,
          color: fill,
          backgroundColor: track,
        ),
      ),
    );
  }
}

class _RacePreview extends StatelessWidget {
  const _RacePreview({
    required this.me,
    required this.todayCount,
    required this.onOpenFriends,
  });

  final UserProfile me;
  final int todayCount;
  final VoidCallback onOpenFriends;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

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
        entries.sort(
          (left, right) => compareLeaderboardEntries(
            left,
            right,
            LeaderboardPeriod.today,
          ),
        );
        final meEntry = entries.firstWhere((entry) => entry.uid == me.uid);
        final hasFriends = entries.length > 1;
        final leader = entries.first;
        final topScore = leader.todayCount;
        final leaders = entries
            .where((entry) => entry.todayCount == topScore)
            .toList();
        final hasUniqueLeader = leaders.length == 1;
        final isAtTop = meEntry.todayCount == topScore;
        final myRank = competitionRank(
          entries,
          meEntry,
          LeaderboardPeriod.today,
        );
        final allAtZero = hasFriends && topScore == 0;

        final title = !hasFriends
            ? 'Race a friend'
            : allAtZero
            ? 'No leader yet today'
            : isAtTop && !hasUniqueLeader
            ? 'You’re tied for the lead'
            : isAtTop
            ? 'You’re leading today'
            : hasUniqueLeader
            ? '${topScore - meEntry.todayCount} reps behind '
                  '@${leader.username}'
            : '${topScore - meEntry.todayCount} reps behind the leaders';
        final detail = !hasFriends
            ? 'Daily, weekly, and all-time boards live here.'
            : allAtZero
            ? 'Everyone starts at 0 · first rep takes the lead'
            : isAtTop && !hasUniqueLeader
            ? 'Tied at $topScore reps · updates after every set'
            : '#$myRank of ${entries.length} · updates after every set';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Friends',
              trailingLabel: hasFriends ? 'View all' : null,
              onTrailingTap: onOpenFriends,
            ),
            const SizedBox(height: AppSpacing.xl),
            PushlogCard(
              onTap: onOpenFriends,
              semanticLabel: '$title. $detail',
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              child: Row(
                children: [
                  if (hasFriends && hasUniqueLeader && topScore > 0)
                    AvatarBadge(
                      initials: leader.initials,
                      seed: leader.uid,
                      isMe: leader.uid == me.uid,
                      rank: 1,
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: theme.accentInk,
                        size: 20,
                      ),
                    ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.title(color: theme.ink),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          detail,
                          style: AppTypography.bodySmall(
                            color: theme.secondaryInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.tertiaryInk,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LifetimeStats extends StatelessWidget {
  const _LifetimeStats({required this.theme, required this.state});

  final AppTheme theme;
  final WorkoutLoaded state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.divider),
          bottom: BorderSide(color: theme.divider),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StatBlock(
              value: '${state.totalAllTime}',
              label: 'All time',
            ),
          ),
          _Rule(theme: theme),
          Expanded(
            child: StatBlock(
              value: '${state.bestDay}',
              label: 'Best day',
            ),
          ),
          _Rule(theme: theme),
          Expanded(
            child: StatBlock(
              value: '${state.streak}d',
              label: 'Streak',
              emphasis: state.streak > 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.theme});

  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: theme.divider,
    );
  }
}
