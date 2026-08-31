import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/live/services/session_duration.dart';

void main() {
  test('uses timestamps when the UI timer was suspended', () {
    final startedAt = DateTime.utc(2026, 8, 31, 10);

    expect(
      finalizedSessionDuration(
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 4, seconds: 12)),
        sampledElapsed: const Duration(seconds: 1),
      ),
      const Duration(minutes: 4, seconds: 12),
    );
  });

  test('does not shorten a newer sampled duration', () {
    final startedAt = DateTime.utc(2026, 8, 31, 10);

    expect(
      finalizedSessionDuration(
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(seconds: 58)),
        sampledElapsed: const Duration(minutes: 1),
      ),
      const Duration(minutes: 1),
    );
  });
}
