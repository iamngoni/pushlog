import 'package:equatable/equatable.dart';
import 'package:pushlog/auth/models/user_profile.dart';

enum LeaderboardPeriod { today, week, allTime }

int compareLeaderboardEntries(
  FriendProfile left,
  FriendProfile right,
  LeaderboardPeriod period,
) {
  final scoreComparison = right
      .scoreFor(period)
      .compareTo(
        left.scoreFor(period),
      );
  if (scoreComparison != 0) return scoreComparison;
  return left.username.toLowerCase().compareTo(right.username.toLowerCase());
}

int competitionRank(
  Iterable<FriendProfile> entries,
  FriendProfile entry,
  LeaderboardPeriod period,
) {
  final score = entry.scoreFor(period);
  return entries
          .where((candidate) => candidate.scoreFor(period) > score)
          .length +
      1;
}

bool scoreIsTied(
  Iterable<FriendProfile> entries,
  FriendProfile entry,
  LeaderboardPeriod period,
) {
  final score = entry.scoreFor(period);
  return entries
          .where((candidate) => candidate.scoreFor(period) == score)
          .length >
      1;
}

class FriendProfile extends Equatable {
  const FriendProfile({
    required this.uid,
    required this.label,
    required this.username,
    required this.todayCount,
    this.weekCount = 0,
    this.totalAllTime = 0,
    this.bestDay = 0,
    this.streak = 0,
    this.photoUrl,
    this.isMe = false,
  });

  factory FriendProfile.fromUserProfile(
    UserProfile profile, {
    bool isMe = false,
    int? todayCount,
    int? weekCount,
    int? totalAllTime,
  }) {
    return FriendProfile(
      uid: profile.uid,
      label: profile.publicLabel,
      username: (profile.username ?? profile.displayName ?? 'pusher').trim(),
      todayCount: todayCount ?? profile.todayCount,
      weekCount: weekCount ?? profile.weekCount,
      totalAllTime: totalAllTime ?? profile.totalAllTime,
      bestDay: profile.bestDay,
      streak: profile.streak,
      photoUrl: profile.photoUrl,
      isMe: isMe,
    );
  }

  final String uid;
  final String label;
  final String username;
  final int todayCount;
  final int weekCount;
  final int totalAllTime;
  final int bestDay;
  final int streak;
  final String? photoUrl;
  final bool isMe;

  String get initials {
    final parts = label
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  int scoreFor(LeaderboardPeriod period) => switch (period) {
    LeaderboardPeriod.today => todayCount,
    LeaderboardPeriod.week => weekCount,
    LeaderboardPeriod.allTime => totalAllTime,
  };

  FriendProfile copyWith({
    String? uid,
    String? label,
    String? username,
    int? todayCount,
    int? weekCount,
    int? totalAllTime,
    int? bestDay,
    int? streak,
    String? photoUrl,
    bool? isMe,
  }) {
    return FriendProfile(
      uid: uid ?? this.uid,
      label: label ?? this.label,
      username: username ?? this.username,
      todayCount: todayCount ?? this.todayCount,
      weekCount: weekCount ?? this.weekCount,
      totalAllTime: totalAllTime ?? this.totalAllTime,
      bestDay: bestDay ?? this.bestDay,
      streak: streak ?? this.streak,
      photoUrl: photoUrl ?? this.photoUrl,
      isMe: isMe ?? this.isMe,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    label,
    username,
    todayCount,
    weekCount,
    totalAllTime,
    bestDay,
    streak,
    photoUrl,
    isMe,
  ];
}
