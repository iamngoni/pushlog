import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/friends/models/friend_profile.dart';

void main() {
  test('public json omits private account and workout fields', () {
    const profile = UserProfile(
      uid: 'uid-1',
      email: 'private@example.com',
      displayName: 'Push Tester',
      photoUrl: 'https://example.com/photo.png',
      username: 'push_tester',
      usernameLower: 'push_tester',
      todayCount: 12,
    );

    final json = profile.toPublicJson();

    expect(json['uid'], 'uid-1');
    expect(json['email'], isNull);
    expect(json['usernameLower'], 'push_tester');
    expect(json.containsKey('todayCount'), isFalse);
    expect(json.containsKey('bestDay'), isFalse);
    expect(json.containsKey('totalAllTime'), isFalse);
    expect(json.containsKey('streak'), isFalse);
  });

  test('friend profile never falls back to email address', () {
    const profile = UserProfile(
      uid: 'uid-1',
      email: 'private@example.com',
    );

    final friend = FriendProfile.fromUserProfile(profile);

    expect(friend.label, 'PUSHER');
    expect(friend.username, 'pusher');
  });
}
