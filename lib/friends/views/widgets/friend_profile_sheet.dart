import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/avatar_badge.dart';
import 'package:pushlog/friends/models/friend_activity.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/history/views/widgets/workout_session_detail.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';

typedef FriendActivityLoader = Future<FriendActivity> Function();

Future<void> showFriendProfileSheet({
  required BuildContext context,
  required AppTheme theme,
  required FriendProfile profile,
  required FriendActivityLoader loadActivity,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.background,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.top(AppRadius.xxl),
    ),
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FriendProfileSheet(
      profile: profile,
      theme: theme,
      loadActivity: loadActivity,
    ),
  );
}

class FriendProfileSheet extends StatefulWidget {
  const FriendProfileSheet({
    required this.profile,
    required this.theme,
    required this.loadActivity,
    super.key,
  });

  final FriendProfile profile;
  final AppTheme theme;
  final FriendActivityLoader loadActivity;

  @override
  State<FriendProfileSheet> createState() => _FriendProfileSheetState();
}

class _FriendProfileSheetState extends State<FriendProfileSheet> {
  late Future<FriendActivity> _activity;

  @override
  void initState() {
    super.initState();
    _activity = widget.loadActivity();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.55,
        maxChildSize: 0.94,
        expand: false,
        builder: (_, scrollController) => FutureBuilder<FriendActivity>(
          future: _activity,
          builder: (context, snapshot) {
            final loadedProfile = snapshot.data?.profile;
            final profile = loadedProfile == null
                ? widget.profile
                : loadedProfile.copyWith(isMe: widget.profile.isMe);
            final sessions = List<WorkoutSession>.from(
              snapshot.data?.sessions ?? const [],
            )..sort((left, right) => right.date.compareTo(left.date));

            return CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.lg,
                    AppSpacing.gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ProfileHeader(
                      profile: profile,
                      theme: widget.theme,
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: widget.theme.accentInk,
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _LoadError(
                      theme: widget.theme,
                      onRetry: () => setState(
                        () => _activity = widget.loadActivity(),
                      ),
                    ),
                  )
                else if (sessions.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.xxl,
                      AppSpacing.gutter,
                      AppSpacing.section,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'No session details have been recorded yet.',
                        style: AppTypography.body(
                          color: widget.theme.secondaryInk,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.md,
                      AppSpacing.gutter,
                      AppSpacing.section,
                    ),
                    sliver: SliverList.builder(
                      itemCount: sessions.length,
                      itemBuilder: (_, index) => WorkoutSessionDetail(
                        session: sessions[index],
                        theme: widget.theme,
                        showDate: true,
                        showDivider: index < sessions.length - 1,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.theme});

  final FriendProfile profile;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.isMe ? 'YOUR PROFILE' : 'FRIEND PROFILE',
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            AvatarBadge(
              initials: profile.initials,
              seed: profile.uid,
              isMe: profile.isMe,
              size: 64,
            ),
            const SizedBox(width: AppSpacing.xxl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.isMe ? 'You' : profile.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headingMedium(color: theme.ink),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '@${profile.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(color: theme.secondaryInk),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        Divider(height: 1, color: theme.divider),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'REP STATS',
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
        const SizedBox(height: AppSpacing.md),
        _ProfileStatRow(
          label: 'Today',
          value: _reps(profile.todayCount),
          theme: theme,
        ),
        _ProfileStatRow(
          label: 'This week',
          value: _reps(profile.weekCount),
          theme: theme,
        ),
        _ProfileStatRow(
          label: 'All time',
          value: _reps(profile.totalAllTime),
          theme: theme,
        ),
        _ProfileStatRow(
          label: 'Best day',
          value: _reps(profile.bestDay),
          theme: theme,
        ),
        _ProfileStatRow(
          label: 'Current streak',
          value: _days(profile.streak),
          theme: theme,
          showDivider: false,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 18,
              color: theme.secondaryInk,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                'Workout details are shared only between accepted friends.',
                style: AppTypography.bodySmall(color: theme.secondaryInk),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        Divider(height: 1, color: theme.divider),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'SESSION HISTORY',
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
      ],
    );
  }

  static String _reps(int value) => '$value ${value == 1 ? 'rep' : 'reps'}';
  static String _days(int value) => '$value ${value == 1 ? 'day' : 'days'}';
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.theme, required this.onRetry});

  final AppTheme theme;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Session history could not be loaded.',
            textAlign: TextAlign.center,
            style: AppTypography.body(color: theme.secondaryInk),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _ProfileStatRow extends StatelessWidget {
  const _ProfileStatRow({
    required this.label,
    required this.value,
    required this.theme,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final AppTheme theme;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.controlHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.body(color: theme.secondaryInk),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: AppTypography.metricInline(color: theme.ink),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: theme.dividerSoft),
      ],
    );
  }
}
