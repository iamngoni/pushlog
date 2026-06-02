import 'package:equatable/equatable.dart';
import 'package:pushlog/auth/models/user_profile.dart';

class FriendProfile extends Equatable {
  const FriendProfile({
    required this.uid,
    required this.label,
    required this.username,
    required this.todayCount,
    this.photoUrl,
    this.isMe = false,
  });

  factory FriendProfile.fromUserProfile(
    UserProfile profile, {
    bool isMe = false,
    int? todayCount,
  }) {
    return FriendProfile(
      uid: profile.uid,
      label: profile.publicLabel,
      username: (profile.username ?? profile.displayName ?? 'pusher').trim(),
      todayCount: todayCount ?? profile.todayCount,
      photoUrl: profile.photoUrl,
      isMe: isMe,
    );
  }

  final String uid;
  final String label;
  final String username;
  final int todayCount;
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

  FriendProfile copyWith({
    String? uid,
    String? label,
    String? username,
    int? todayCount,
    String? photoUrl,
    bool? isMe,
  }) {
    return FriendProfile(
      uid: uid ?? this.uid,
      label: label ?? this.label,
      username: username ?? this.username,
      todayCount: todayCount ?? this.todayCount,
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
    photoUrl,
    isMe,
  ];
}
