import 'package:equatable/equatable.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';

class FriendActivity extends Equatable {
  const FriendActivity({
    required this.profile,
    required this.dayTotals,
    required this.sessions,
  });

  factory FriendActivity.fromJson(Map<String, dynamic> json) {
    final profileValue = json['profile'];
    final dayTotalsValue = json['dayTotals'];
    final sessionsValue = json['sessions'];
    if (profileValue is! Map) {
      throw const FormatException('Friend activity has no profile.');
    }

    return FriendActivity(
      profile: FriendProfile.fromUserProfile(
        UserProfile.fromJson(Map<String, dynamic>.from(profileValue)),
      ),
      dayTotals: dayTotalsValue is Map
          ? dayTotalsValue.map(
              (key, value) => MapEntry(
                key.toString(),
                value is num ? value.toInt() : 0,
              ),
            )
          : const {},
      sessions: sessionsValue is List
          ? sessionsValue
                .whereType<Map<Object?, Object?>>()
                .map(
                  (session) => WorkoutSession.fromJson(
                    Map<String, dynamic>.from(session),
                  ),
                )
                .toList()
          : const [],
    );
  }

  final FriendProfile profile;
  final Map<String, int> dayTotals;
  final List<WorkoutSession> sessions;

  @override
  List<Object> get props => [profile, dayTotals, sessions];
}
