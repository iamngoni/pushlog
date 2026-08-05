import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/friends/models/friend_profile.dart';

void main() {
  const profile = FriendProfile(
    uid: 'friend',
    label: 'Friend',
    username: 'friend',
    todayCount: 18,
    weekCount: 94,
    totalAllTime: 4200,
  );

  test('selects the score for each leaderboard period', () {
    expect(profile.scoreFor(LeaderboardPeriod.today), 18);
    expect(profile.scoreFor(LeaderboardPeriod.week), 94);
    expect(profile.scoreFor(LeaderboardPeriod.allTime), 4200);
  });
}
