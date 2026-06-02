import 'package:equatable/equatable.dart';
import 'package:pushlog/auth/models/user_profile.dart';

class FriendRequest extends Equatable {
  const FriendRequest({
    required this.uid,
    required this.username,
    required this.label,
    this.photoUrl,
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final username = json['username'] as String?;
    final displayName = json['displayName'] as String?;
    final label = (username ?? displayName ?? 'Pusher').trim();
    return FriendRequest(
      uid: json['uid'] as String,
      username: (username ?? displayName ?? 'pusher').trim(),
      label: label.isEmpty ? 'Pusher' : label,
      photoUrl: json['photoUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  factory FriendRequest.fromUserProfile(UserProfile profile) {
    return FriendRequest(
      uid: profile.uid,
      username: (profile.username ?? profile.displayName ?? 'pusher').trim(),
      label: profile.publicLabel,
      photoUrl: profile.photoUrl,
    );
  }

  final String uid;
  final String username;
  final String label;
  final String? photoUrl;
  final DateTime? createdAt;

  Map<String, dynamic> toJson({DateTime? createdAt}) => {
    'uid': uid,
    'username': username,
    'usernameLower': username.toLowerCase(),
    'displayName': label,
    'photoUrl': photoUrl,
    'createdAt': (createdAt ?? this.createdAt ?? DateTime.now())
        .toIso8601String(),
  };

  @override
  List<Object?> get props => [
    uid,
    username,
    label,
    photoUrl,
    createdAt,
  ];
}
