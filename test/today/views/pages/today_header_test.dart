import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/today/views/pages/today_page.dart';

UserProfile _profile({String? displayName, String? username}) {
  return UserProfile(
    uid: 'uid-1',
    displayName: displayName,
    username: username,
  );
}

void main() {
  group('greetingFor', () {
    test('changes across the day', () {
      expect(greetingFor(DateTime(2026, 8, 19, 8)), 'Good morning');
      expect(greetingFor(DateTime(2026, 8, 19, 13)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 8, 19, 20)), 'Good evening');
    });

    test('boundaries land on the later greeting', () {
      // Midnight is still morning, and each cutover belongs to the band it
      // opens rather than the one it closes.
      expect(greetingFor(DateTime(2026, 8, 19)), 'Good morning');
      expect(greetingFor(DateTime(2026, 8, 19, 11, 59)), 'Good morning');
      expect(greetingFor(DateTime(2026, 8, 19, 12)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 8, 19, 16, 59)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 8, 19, 17)), 'Good evening');
      expect(greetingFor(DateTime(2026, 8, 19, 23, 59)), 'Good evening');
    });
  });

  group('greetingName', () {
    test('uses the first name from a display name', () {
      expect(
        greetingName(_profile(displayName: 'George T Chakama')),
        'George',
      );
    });

    test('prefers the display name over the username', () {
      expect(
        greetingName(_profile(displayName: 'Dev Tester', username: 'devt')),
        'Dev',
      );
    });

    test('falls back to the username when there is no display name', () {
      expect(greetingName(_profile(username: 'devtester')), 'devtester');
    });

    test('treats blank values as absent', () {
      expect(greetingName(_profile(displayName: '   ')), null);
      expect(
        greetingName(_profile(displayName: '  ', username: 'devtester')),
        'devtester',
      );
    });

    test('is null with no profile, so the greeting stands alone', () {
      expect(greetingName(null), null);
    });
  });
}
