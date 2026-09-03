import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/auth/services/profile_service.dart';

void main() {
  group('ProfileService.normalizeUsername', () {
    test('lowercases valid usernames', () {
      expect(
        ProfileService.normalizeUsername('PushKing'),
        'pushking',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        ProfileService.normalizeUsername('  push_king_99  '),
        'push_king_99',
      );
    });

    test('keeps letters, digits, and underscores', () {
      expect(
        ProfileService.normalizeUsername('a1_b2_c3'),
        'a1_b2_c3',
      );
    });

    test('rejects usernames shorter than 3 characters', () {
      expect(ProfileService.normalizeUsername('ab'), isNull);
    });

    test('rejects usernames longer than 20 characters', () {
      expect(
        ProfileService.normalizeUsername('a' * 21),
        isNull,
      );
      expect(
        ProfileService.normalizeUsername('a' * 20),
        'a' * 20,
      );
    });

    test('rejects special characters and spaces', () {
      expect(ProfileService.normalizeUsername('push king'), isNull);
      expect(ProfileService.normalizeUsername('push-king'), isNull);
      expect(ProfileService.normalizeUsername('push.king'), isNull);
      expect(ProfileService.normalizeUsername('@pushking'), isNull);
    });

    test('rejects empty input', () {
      expect(ProfileService.normalizeUsername(''), isNull);
      expect(ProfileService.normalizeUsername('   '), isNull);
    });
  });
}
