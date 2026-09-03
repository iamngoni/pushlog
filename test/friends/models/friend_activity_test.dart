import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/friends/models/friend_activity.dart';

void main() {
  test('parses friend profile and detailed live session', () {
    final activity = FriendActivity.fromJson(const {
      'profile': {
        'uid': 'friend-1',
        'displayName': 'Friend One',
        'username': 'friend_one',
        'usernameLower': 'friend_one',
        'todayCount': 12,
        'weekCount': 42,
        'totalAllTime': 420,
        'bestDay': 80,
        'streak': 6,
      },
      'dayTotals': {'2026-08-06': 12},
      'sessions': [
        {
          'id': 'live-1',
          'date': '2026-08-06T17:38:00.000',
          'reps': 12,
          'source': 'live',
          'duration': 28000000,
          'averageRepDuration': 2000000,
          'manualAdjustments': 3,
          'effortScore': 8,
          'latestHeartRate': 142.5,
          'activeCalories': 18.75,
        },
      ],
    });

    expect(activity.profile.uid, 'friend-1');
    expect(activity.profile.totalAllTime, 420);
    expect(activity.dayTotals['2026-08-06'], 12);
    expect(activity.sessions.single.duration, const Duration(seconds: 28));
    expect(activity.sessions.single.effortScore, 8);
    expect(activity.sessions.single.latestHeartRate, 142.5);
    expect(activity.sessions.single.activeCalories, 18.75);
  });
}
