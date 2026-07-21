import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/models/friend_request.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';

class FriendsLeaderboard extends StatelessWidget {
  const FriendsLeaderboard({
    required this.theme,
    required this.me,
    required this.todayCount,
    super.key,
  });

  final AppTheme theme;
  final UserProfile me;
  final int todayCount;

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
                      ),
                    ]
                  : state.leaderboard
                        .map(
                          (entry) => entry.uid == me.uid
                              ? entry.copyWith(todayCount: todayCount)
                              : entry,
                        )
                        .toList()
              ..sort(
                (left, right) => right.todayCount.compareTo(left.todayCount),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'FRIENDS TODAY',
                  style: AppTypography.labelMono(
                    color: theme.secondaryInk,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => unawaited(
                    _showFriendSheet(context),
                  ),
                  child: Text(
                    'INVITE',
                    style: AppTypography.labelMono(
                      color: theme.accentInk,
                      weight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.divider),
                  color: theme.surface,
                ),
                child: Column(
                  children: [
                    for (final indexedEntry in leaderboard.take(5).indexed)
                      _LeaderboardRow(
                        rank: indexedEntry.$1 + 1,
                        entry: indexedEntry.$2,
                        theme: theme,
                        onRemove: indexedEntry.$2.isMe
                            ? null
                            : () =>
                                  context.read<FriendsCubit>().revokeFriendship(
                                    me: me,
                                    todayCount: todayCount,
                                    friendUid: indexedEntry.$2.uid,
                                  ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showFriendSheet(
    BuildContext context,
  ) {
    final cubit = context.read<FriendsCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.theme,
    this.onRemove,
  });

  final int rank;
  final FriendProfile entry;
  final AppTheme theme;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.divider),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: AppTypography.labelMono(
                color: theme.secondaryInk,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.isMe ? theme.accent : theme.divider,
            ),
            child: Text(
              entry.initials,
              style: AppTypography.labelMono(
                size: 8,
                color: entry.isMe ? AppColors.fixedDark : theme.ink,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label.toUpperCase(),
                  style: AppTypography.labelMono(
                    color: entry.isMe ? theme.ink : theme.secondaryInk,
                    letterSpacing: 1.1,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${entry.username}',
                  style: AppTypography.labelMono(
                    size: 9,
                    color: theme.secondaryInk,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.todayCount}',
            style: AppTypography.labelMono(
              size: 13,
              color: entry.isMe ? theme.accentInk : theme.ink,
              weight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onRemove,
              child: Text(
                'X',
                style: AppTypography.labelMono(
                  color: theme.secondaryInk,
                ),
              ),
            ),
          ],
        ],
      ),
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
                      'FRIENDS',
                      style: AppTypography.displayCompact(
                        color: widget.theme.ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('REQUESTS'),
                    const SizedBox(height: 8),
                    if (state.incomingRequests.isEmpty)
                      _emptyText('NO OPEN REQUESTS.')
                    else
                      for (final request in state.incomingRequests)
                        _requestRow(
                          request,
                          primary: 'ACCEPT',
                          onPrimary: () => unawaited(
                            cubit.acceptFriendRequest(
                              me: widget.me,
                              todayCount: widget.todayCount,
                              requester: request,
                            ),
                          ),
                          secondary: 'DECLINE',
                          onSecondary: () => unawaited(
                            cubit.declineFriendRequest(
                              me: widget.me,
                              todayCount: widget.todayCount,
                              requesterUid: request.uid,
                            ),
                          ),
                        ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _controller,
                      autocorrect: false,
                      style: AppTypography.displayAction(
                        color: widget.theme.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: '@username',
                        hintStyle: AppTypography.displayAction(
                          color: widget.theme.secondaryInk,
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
                    const SizedBox(height: 14),
                    _searchResults(state, cubit),
                    const SizedBox(height: 22),
                    _sectionTitle('CAN SEE YOUR STATS'),
                    const SizedBox(height: 8),
                    if (acceptedFriends.isEmpty)
                      _emptyText('NO ACCEPTED FRIENDS.')
                    else
                      for (final friend in acceptedFriends)
                        _friendRow(
                          friend,
                          action: 'REVOKE',
                          onAction: () => unawaited(
                            cubit.revokeFriendship(
                              me: widget.me,
                              todayCount: widget.todayCount,
                              friendUid: friend.uid,
                            ),
                          ),
                        ),
                    if (state.outgoingRequests.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _sectionTitle('SENT'),
                      const SizedBox(height: 8),
                      for (final request in state.outgoingRequests)
                        _requestRow(
                          request,
                          primary: 'CANCEL',
                          onPrimary: () => unawaited(
                            cubit.cancelFriendRequest(
                              me: widget.me,
                              todayCount: widget.todayCount,
                              receiverUid: request.uid,
                            ),
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

  Widget _searchResults(FriendsState state, FriendsCubit cubit) {
    if (state.isSearching) {
      return LinearProgressIndicator(
        minHeight: 2,
        color: widget.theme.accent,
        backgroundColor: widget.theme.divider,
      );
    }

    if (state.searchQuery.trim().length < 2) {
      return _emptyText('SEARCH BY USERNAME.');
    }

    if (state.searchResults.isEmpty) {
      return _emptyText('NO MATCHES.');
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
          bottom: BorderSide(color: widget.theme.divider),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.labelMono(
                    color: widget.theme.ink,
                    weight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: AppTypography.labelMono(
                    size: 9,
                    color: widget.theme.secondaryInk,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          if (secondaryAction != null) ...[
            GestureDetector(
              onTap: onSecondaryAction,
              child: Text(
                secondaryAction,
                style: AppTypography.labelMono(
                  color: widget.theme.secondaryInk,
                  weight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          GestureDetector(
            onTap: onAction,
            child: Text(
              action,
              style: AppTypography.labelMono(
                color: onAction == null
                    ? widget.theme.secondaryInk
                    : widget.theme.accentInk,
                weight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.labelMono(
        color: widget.theme.secondaryInk,
        weight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
  }

  Widget _emptyText(String message) {
    return Text(
      message,
      style: AppTypography.labelMono(
        color: widget.theme.secondaryInk,
        letterSpacing: 1.1,
      ),
    );
  }

  FriendRequest? _incomingRequestFor(FriendsState state, String uid) {
    for (final request in state.incomingRequests) {
      if (request.uid == uid) return request;
    }
    return null;
  }
}
