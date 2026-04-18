import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/auth/services/profile_service.dart';

void main() {
  group('ProfileService.normalizeUsername', () {
    test('accepts lowercase usernames', () {
      expect(
        ProfileService.normalizeUsername('push_master'),
        'push_master',
      );
    });

    test('normalizes uppercase usernames', () {
      expect(
        ProfileService.normalizeUsername('PUSHLOG'),
        'pushlog',
      );
    });

    test('rejects invalid usernames', () {
      expect(
        ProfileService.normalizeUsername('no spaces'),
        isNull,
      );
      expect(
        ProfileService.normalizeUsername('ab'),
        isNull,
      );
    });
  });
}
