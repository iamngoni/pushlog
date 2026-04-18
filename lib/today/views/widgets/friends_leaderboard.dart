import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
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
        if (!state.isLoading &&
            state.leaderboard.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.read<FriendsCubit>().load(
                  me: me,
                  todayCount: todayCount,
                );
          });
        }
        final leaderboard = state.leaderboard.isEmpty
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
                (left, right) => right.todayCount
                    .compareTo(left.todayCount),
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
                  onTap: () =>
                      _showFriendSheet(context, state),
                  child: Text(
                    'ADD',
                    style: AppTypography.labelMono(
                      size: 10,
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
                    for (final indexedEntry
                        in leaderboard.take(5).indexed)
                      _LeaderboardRow(
                        rank: indexedEntry.$1 + 1,
                        entry: indexedEntry.$2,
                        theme: theme,
                        onRemove: indexedEntry.$2.isMe
                            ? null
                            : () => context
                                .read<FriendsCubit>()
                                .removeFriend(
                                  me: me,
                                  todayCount: todayCount,
                                  friendUid:
                                      indexedEntry.$2.uid,
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
    FriendsState state,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.background,
      builder: (_) => _FriendSearchSheet(
        theme: theme,
        me: me,
        todayCount: todayCount,
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
                size: 10,
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
              color: entry.isMe
                  ? theme.accent
                  : theme.divider,
            ),
            child: Text(
              entry.initials,
              style: AppTypography.labelMono(
                size: 8,
                color: entry.isMe
                    ? AppColors.fixedDark
                    : theme.ink,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label.toUpperCase(),
                  style: AppTypography.labelMono(
                    size: 11,
                    color: entry.isMe
                        ? theme.ink
                        : theme.secondaryInk,
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
              color: entry.isMe
                  ? theme.accentInk
                  : theme.ink,
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
                  size: 11,
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
  State<_FriendSearchSheet> createState() =>
      _FriendSearchSheetState();
}

class _FriendSearchSheetState
    extends State<_FriendSearchSheet> {
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
    return Padding(
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        top: 24,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: BlocBuilder<FriendsCubit, FriendsState>(
        builder: (context, state) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'ADD FRIEND',
                style: AppTypography.displayCompact(
                  color: widget.theme.ink,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autocorrect: false,
                textCapitalization:
                    TextCapitalization.none,
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
              if (state.isSearching)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: widget.theme.accent,
                  backgroundColor: widget.theme.divider,
                )
              else if (state.searchQuery.trim().length < 2)
                Text(
                  'TYPE AT LEAST 2 CHARACTERS.',
                  style: AppTypography.labelMono(
                    color: widget.theme.secondaryInk,
                    letterSpacing: 1.1,
                  ),
                )
              else if (state.searchResults.isEmpty)
                Text(
                  'NO MATCHES.',
                  style: AppTypography.labelMono(
                    color: widget.theme.secondaryInk,
                    letterSpacing: 1.1,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 320,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.searchResults.length,
                    separatorBuilder: (_, _) => Divider(
                      color: widget.theme.divider,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final profile =
                          state.searchResults[index];
                      final isFriend =
                          state.friendIds.contains(
                        profile.uid,
                      );
                      return ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        title: Text(
                          profile.label.toUpperCase(),
                          style:
                              AppTypography.labelMono(
                            size: 11,
                            color: widget.theme.ink,
                            weight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        subtitle: Text(
                          '@${profile.username}',
                          style:
                              AppTypography.labelMono(
                            size: 9,
                            color:
                                widget.theme.secondaryInk,
                            letterSpacing: 1,
                          ),
                        ),
                        trailing: GestureDetector(
                          onTap: isFriend
                              ? null
                              : () => cubit.addFriend(
                                    me: widget.me,
                                    todayCount:
                                        widget.todayCount,
                                    friend: profile,
                                  ),
                          child: Text(
                            isFriend ? 'ADDED' : 'ADD',
                            style: AppTypography.labelMono(
                              size: 10,
                              color: isFriend
                                  ? widget
                                      .theme.secondaryInk
                                  : widget
                                      .theme.accentInk,
                              weight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
