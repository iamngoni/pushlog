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

  test('uses competition ranks for ties instead of list positions', () {
    const tied = [
      FriendProfile(
        uid: 'alpha',
        label: 'Alpha',
        username: 'alpha',
        todayCount: 0,
      ),
      FriendProfile(
        uid: 'beta',
        label: 'Beta',
        username: 'beta',
        todayCount: 0,
      ),
    ];

    expect(
      competitionRank(tied, tied.first, LeaderboardPeriod.today),
      1,
    );
    expect(
      competitionRank(tied, tied.last, LeaderboardPeriod.today),
      1,
    );
    expect(scoreIsTied(tied, tied.first, LeaderboardPeriod.today), isTrue);
  });

  test('skips tied places when calculating the next rank', () {
    const entries = [
      FriendProfile(
        uid: 'alpha',
        label: 'Alpha',
        username: 'alpha',
        todayCount: 12,
      ),
      FriendProfile(
        uid: 'beta',
        label: 'Beta',
        username: 'beta',
        todayCount: 12,
      ),
      FriendProfile(
        uid: 'gamma',
        label: 'Gamma',
        username: 'gamma',
        todayCount: 7,
      ),
    ];

    expect(
      competitionRank(entries, entries.last, LeaderboardPeriod.today),
      3,
    );
  });
}
