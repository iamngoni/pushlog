import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/avatar_badge.dart';
import 'package:pushlog/core/views/widgets/empty_state.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';
import 'package:pushlog/core/views/widgets/pushlog_confirm_dialog.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/models/friend_request.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';

class FriendsLeaderboard extends StatelessWidget {
  const FriendsLeaderboard({
    required this.theme,
    required this.me,
    required this.todayCount,
    this.weekCount = 0,
    this.totalAllTime = 0,
    this.period = LeaderboardPeriod.today,
    this.showHeader = true,
    this.limit,
    super.key,
  });

  final AppTheme theme;
  final UserProfile me;
  final int todayCount;
  final int weekCount;
  final int totalAllTime;
  final LeaderboardPeriod period;
  final bool showHeader;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FriendsCubit, FriendsState>(
      builder: (context, state) {
        if (!state.isLoading && state.leaderboard.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            unawaited(
              context.read<FriendsCubit>().load(
                me: me,
                todayCount: todayCount,
                weekCount: weekCount,
                totalAllTime: totalAllTime,
              ),
            );
          });
        }
        final leaderboard =
            state.leaderboard.isEmpty
                  ? [
                      FriendProfile.fromUserProfile(
                        me,
                        isMe: true,
                        todayCount: todayCount,
                        weekCount: weekCount,
                        totalAllTime: totalAllTime,
                      ),
                    ]
                  : state.leaderboard
                        .map(
                          (entry) => entry.uid == me.uid
                              ? entry.copyWith(
                                  todayCount: todayCount,
                                  weekCount: weekCount,
                                  totalAllTime: totalAllTime,
                                )
                              : entry,
                        )
                        .toList()
              ..sort(
                (left, right) => compareLeaderboardEntries(left, right, period),
              );
        final visibleEntries = limit == null
            ? leaderboard
            : leaderboard.take(limit!).toList();
        final hasRankedScore = leaderboard.any(
          (entry) => entry.scoreFor(period) > 0,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                children: [
                  Text(
                    _periodHeading(period),
                    style: AppTypography.title(color: theme.ink),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => unawaited(
                      showFriendManagerSheet(
                        context: context,
                        theme: theme,
                        me: me,
                        todayCount: todayCount,
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Invite'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.accentInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (state.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: theme.accent,
                  backgroundColor: theme.divider,
                ),
              )
            else if (visibleEntries.length == 1)
              _EmptyLeaderboard(
                theme: theme,
                onInvite: () => unawaited(
                  showFriendManagerSheet(
                    context: context,
                    theme: theme,
                    me: me,
                    todayCount: todayCount,
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final indexedEntry in visibleEntries.indexed)
                    _LeaderboardRow(
                      competitionRank: hasRankedScore
                          ? competitionRank(
                              leaderboard,
                              indexedEntry.$2,
                              period,
                            )
                          : null,
                      isTied: scoreIsTied(
                        leaderboard,
                        indexedEntry.$2,
                        period,
                      ),
                      entry: indexedEntry.$2,
                      period: period,
                      theme: theme,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

String _periodHeading(LeaderboardPeriod period) => switch (period) {
  LeaderboardPeriod.today => 'Today',
  LeaderboardPeriod.week => 'This week',
  LeaderboardPeriod.allTime => 'All time',
};

Future<void> showFriendManagerSheet({
  required BuildContext context,
  required AppTheme theme,
  required UserProfile me,
  required int todayCount,
}) {
  final cubit = context.read<FriendsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: theme.background,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _FriendSearchSheet(
        theme: theme,
        me: me,
        todayCount: todayCount,
      ),
    ),
  );
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.competitionRank,
    required this.isTied,
    required this.entry,
    required this.period,
    required this.theme,
  });

  final int? competitionRank;
  final bool isTied;
  final FriendProfile entry;
  final LeaderboardPeriod period;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final score = entry.scoreFor(period);
    final rankLabel = competitionRank == null
        ? '—'
        : isTied
        ? 'T$competitionRank'
        : '$competitionRank';
    final rankDescription = competitionRank == null
        ? 'not ranked yet'
        : isTied
        ? 'tied at rank $competitionRank'
        : 'rank $competitionRank';

    return Semantics(
      label:
          '${entry.isMe ? 'You' : entry.label}, '
          '$rankDescription, $score reps',
      excludeSemantics: true,
      child: Container(
        // The row that is *you* gets a tinted band. On a list where every
        // entry looks alike, finding yourself should not require reading.
        color: entry.isMe ? theme.accentSoft : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                rankLabel,
                style: AppTypography.metricInline(
                  color: (competitionRank ?? 4) <= 3
                      ? theme.ink
                      : theme.tertiaryInk,
                  weight: (competitionRank ?? 4) <= 3
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AvatarBadge(
              initials: entry.initials,
              seed: entry.uid,
              isMe: entry.isMe,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.isMe ? 'You' : entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.title(color: theme.ink),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '@${entry.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall(
                      color: theme.secondaryInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(
              _formatScore(score),
              style: AppTypography.metricSmall(
                color: entry.isMe ? theme.accentInk : theme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatScore(int score) {
  if (score >= 1000000) return '${(score / 1000000).toStringAsFixed(1)}m';
  if (score >= 10000) return '${(score / 1000).toStringAsFixed(1)}k';
  return '$score';
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard({required this.theme, required this.onInvite});

  final AppTheme theme;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      compact: true,
      icon: Icons.groups_rounded,
      title: 'No one to race yet',
      message:
          'Add a friend by username and you will both see who is '
          'ahead today, this week, and all time.',
      actionLabel: 'Find a friend',
      onAction: onInvite,
    );
  }
}

class _FriendSearchSheet extends StatefulWidget {
  const _FriendSearchSheet({
    required this.theme,
    required this.me,
    required this.todayCount,
  });

  final AppTheme theme;
  final UserProfile me;
  final int todayCount;

  @override
  State<_FriendSearchSheet> createState() => _FriendSearchSheetState();
}

class _FriendSearchSheetState extends State<_FriendSearchSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FriendsCubit>();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.84;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 28,
          right: 28,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: BlocBuilder<FriendsCubit, FriendsState>(
            builder: (context, state) {
              final acceptedFriends = state.leaderboard
                  .where((entry) => !entry.isMe)
                  .toList();

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Friends',
                      style: AppTypography.headingLarge(
                        color: widget.theme.ink,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.block),
                    _sectionTitle('REQUESTS'),
                    const SizedBox(height: AppSpacing.md),
                    if (state.incomingRequests.isEmpty)
                      _emptyText('No open requests.')
                    else
                      for (final request in state.incomingRequests)
                        _requestRow(
                          request,
                          primary: 'Accept',
                          onPrimary: () => unawaited(
                            cubit.acceptFriendRequest(
                              me: widget.me,
                              todayCount: widget.todayCount,
                              requester: request,
                            ),
                          ),
                          secondary: 'Decline',
                          onSecondary: () => unawaited(
                            _confirmDecline(request, cubit),
                          ),
                        ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextField(
                      controller: _controller,
                      autocorrect: false,
                      style: AppTypography.headingSmall(
                        color: widget.theme.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: '@username',
                        hintStyle: AppTypography.headingSmall(
                          color: widget.theme.tertiaryInk,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.theme.divider,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: widget.theme.accent,
                          ),
                        ),
                      ),
                      onChanged: (value) => cubit.search(
                        me: widget.me,
                        query: value.replaceAll('@', ''),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _searchResults(state, cubit),
                    const SizedBox(height: AppSpacing.block),
                    _sectionTitle('CAN SEE YOUR STATS'),
                    const SizedBox(height: AppSpacing.md),
                    if (acceptedFriends.isEmpty)
                      _emptyText('No friends added yet.')
                    else
                      for (final friend in acceptedFriends)
                        _friendRow(
                          friend,
                          action: 'REVOKE',
                          onAction: () => unawaited(
                            _confirmRevoke(friend, cubit),
                          ),
                        ),
                    if (state.outgoingRequests.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.block),
                      _sectionTitle('SENT'),
                      const SizedBox(height: AppSpacing.md),
                      for (final request in state.outgoingRequests)
                        _requestRow(
                          request,
                          primary: 'CANCEL',
                          onPrimary: () => unawaited(
                            _confirmCancelRequest(request, cubit),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Unfriending is one-sided and final. Only a fresh request undoes it,
  /// and only the other person can accept that — so the tap that starts it
  /// is worth one question.
  Future<void> _confirmRevoke(
    FriendProfile friend,
    FriendsCubit cubit,
  ) async {
    final confirmed = await PushlogConfirmDialog.ask(
      context,
      title: 'Remove @${friend.username}?',
      message:
          "You will drop off each other's leaderboards. Adding them back "
          'means sending a new request and waiting for them to accept.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;
    await cubit.revokeFriendship(
      me: widget.me,
      todayCount: widget.todayCount,
      friendUid: friend.uid,
    );
  }

  /// Decline sits directly beside Accept, so a mis-tap here is an ordinary
  /// slip with a consequence the user cannot reverse on their own.
  Future<void> _confirmDecline(
    FriendRequest request,
    FriendsCubit cubit,
  ) async {
    final confirmed = await PushlogConfirmDialog.ask(
      context,
      title: 'Decline @${request.username}?',
      message: 'The request leaves your list. Only they can send it again.',
      confirmLabel: 'Decline',
    );
    if (!confirmed || !mounted) return;
    await cubit.declineFriendRequest(
      me: widget.me,
      todayCount: widget.todayCount,
      requesterUid: request.uid,
    );
  }

  Future<void> _confirmCancelRequest(
    FriendRequest request,
    FriendsCubit cubit,
  ) async {
    final confirmed = await PushlogConfirmDialog.ask(
      context,
      title: 'Cancel your request to @${request.username}?',
      message: 'They will stop seeing it. You can send a new one later.',
      // 'Cancel' would read as both answers here, so the way out says
      // what keeping the request actually means.
      cancelLabel: 'Keep it',
      confirmLabel: 'Cancel request',
      isDestructive: false,
    );
    if (!confirmed || !mounted) return;
    await cubit.cancelFriendRequest(
      me: widget.me,
      todayCount: widget.todayCount,
      receiverUid: request.uid,
    );
  }

  Widget _searchResults(FriendsState state, FriendsCubit cubit) {
    if (state.isSearching) {
      return LinearProgressIndicator(
        minHeight: 2,
        color: widget.theme.accent,
        backgroundColor: widget.theme.divider,
      );
    }

    if (state.searchQuery.trim().length < 2) {
      return _emptyText('Search for a friend by username.');
    }

    if (state.searchResults.isEmpty) {
      return _emptyText('No one matches that username.');
    }

    return Column(
      children: [
        for (final profile in state.searchResults)
          _searchResultRow(profile, state, cubit),
      ],
    );
  }

  Widget _searchResultRow(
    UserProfile profile,
    FriendsState state,
    FriendsCubit cubit,
  ) {
    final incomingRequest = _incomingRequestFor(state, profile.uid);
    final isFriend = state.friendIds.contains(profile.uid);
    final isOutgoing = state.outgoingRequestIds.contains(profile.uid);
    final action = isFriend
        ? 'FRIEND'
        : isOutgoing
        ? 'SENT'
        : incomingRequest != null
        ? 'ACCEPT'
        : 'REQUEST';
    final onAction = isFriend || isOutgoing
        ? null
        : incomingRequest != null
        ? () => unawaited(
            cubit.acceptFriendRequest(
              me: widget.me,
              todayCount: widget.todayCount,
              requester: incomingRequest,
            ),
          )
        : () => unawaited(
            cubit.sendFriendRequest(
              me: widget.me,
              todayCount: widget.todayCount,
              receiver: profile,
            ),
          );

    return _personRow(
      label: profile.label,
      username: profile.username ?? profile.displayName ?? 'pusher',
      action: action,
      onAction: onAction,
    );
  }

  Widget _requestRow(
    FriendRequest request, {
    required String primary,
    VoidCallback? onPrimary,
    String? secondary,
    VoidCallback? onSecondary,
  }) {
    return _personRow(
      label: request.label,
      username: request.username,
      action: primary,
      onAction: onPrimary,
      secondaryAction: secondary,
      onSecondaryAction: onSecondary,
    );
  }

  Widget _friendRow(
    FriendProfile friend, {
    required String action,
    VoidCallback? onAction,
  }) {
    return _personRow(
      label: friend.label,
      username: friend.username,
      action: action,
      onAction: onAction,
    );
  }

  Widget _personRow({
    required String label,
    required String username,
    required String action,
    VoidCallback? onAction,
    String? secondaryAction,
    VoidCallback? onSecondaryAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: widget.theme.dividerSoft),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          AvatarBadge(initials: _initialsOf(label), seed: username, size: 36),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title(color: widget.theme.ink),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall(
                    color: widget.theme.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Real buttons rather than bare tappable text: these sit side by
          // side and each needs a target a thumb can hit without landing
          // on the other one.
          if (secondaryAction != null) ...[
            PushlogButton(
              label: secondaryAction,
              expand: false,
              size: PushlogButtonSize.small,
              variant: PushlogButtonVariant.ghost,
              onPressed: onSecondaryAction,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          PushlogButton(
            label: action,
            expand: false,
            size: PushlogButtonSize.small,
            variant: onAction == null
                ? PushlogButtonVariant.ghost
                : PushlogButtonVariant.primary,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }

  String _initialsOf(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.overline(color: widget.theme.tertiaryInk),
    );
  }

  Widget _emptyText(String message) => EmptyLine(message);

  FriendRequest? _incomingRequestFor(FriendsState state, String uid) {
    for (final request in state.incomingRequests) {
      if (request.uid == uid) return request;
    }
    return null;
  }
}
