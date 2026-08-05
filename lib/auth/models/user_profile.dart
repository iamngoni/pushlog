import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.username,
    this.usernameLower,
    this.todayCount = 0,
    this.weekCount = 0,
    this.totalAllTime = 0,
    this.bestDay = 0,
    this.streak = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      username: json['username'] as String?,
      usernameLower: json['usernameLower'] as String?,
      todayCount: (json['todayCount'] as num?)?.toInt() ?? 0,
      weekCount: (json['weekCount'] as num?)?.toInt() ?? 0,
      totalAllTime: (json['totalAllTime'] as num?)?.toInt() ?? 0,
      bestDay: (json['bestDay'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? username;
  final String? usernameLower;
  final int todayCount;
  final int weekCount;
  final int totalAllTime;
  final int bestDay;
  final int streak;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get needsUsername => username == null || username!.trim().isEmpty;

  String get label {
    final resolved = username ?? displayName ?? email ?? 'PUSHER';
    return resolved.trim().isEmpty ? 'PUSHER' : resolved;
  }

  String get publicLabel {
    final resolved = username ?? displayName ?? 'PUSHER';
    return resolved.trim().isEmpty ? 'PUSHER' : resolved;
  }

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

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'username': username,
    'usernameLower': usernameLower,
    'todayCount': todayCount,
    'weekCount': weekCount,
    'totalAllTime': totalAllTime,
    'bestDay': bestDay,
    'streak': streak,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> toPublicJson() => {
    'uid': uid,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'username': username,
    'usernameLower': usernameLower,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? username,
    String? usernameLower,
    int? todayCount,
    int? weekCount,
    int? totalAllTime,
    int? bestDay,
    int? streak,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      username: username ?? this.username,
      usernameLower: usernameLower ?? this.usernameLower,
      todayCount: todayCount ?? this.todayCount,
      weekCount: weekCount ?? this.weekCount,
      totalAllTime: totalAllTime ?? this.totalAllTime,
      bestDay: bestDay ?? this.bestDay,
      streak: streak ?? this.streak,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    email,
    displayName,
    photoUrl,
    username,
    usernameLower,
    todayCount,
    weekCount,
    totalAllTime,
    bestDay,
    streak,
    createdAt,
    updatedAt,
  ];
}
