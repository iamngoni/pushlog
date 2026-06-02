import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';

void main() {
  group('WorkoutSnapshot', () {
    test('normalizes day totals from sessions', () {
      final snapshot = WorkoutSnapshot(
        dayTotals: const {
          '2026-05-28': 99,
          '2026-05-29': 1,
        },
        sessions: [
          WorkoutSession(
            id: 'manual-a',
            date: DateTime(2026, 5, 29, 8),
            reps: 10,
            source: WorkoutSource.manual,
          ),
          WorkoutSession(
            id: 'live-a',
            date: DateTime(2026, 5, 29, 18),
            reps: 5,
            source: WorkoutSource.live,
          ),
        ],
      );

      final normalized = snapshot.normalized();

      expect(normalized.dayTotals, {'2026-05-29': 15});
      expect(normalized.sessions.map((session) => session.id), [
        'live-a',
        'manual-a',
      ]);
    });

    test('mergeWith unions sessions and rebuilds day totals', () {
      final local = WorkoutSnapshot(
        updatedAt: DateTime(2026, 5, 30, 12),
        sessions: [
          WorkoutSession(
            id: 'local-new',
            date: DateTime(2026, 5, 30, 12),
            reps: 7,
            source: WorkoutSource.manual,
          ),
          WorkoutSession(
            id: 'shared',
            date: DateTime(2026, 5, 29, 10),
            reps: 4,
            source: WorkoutSource.manual,
          ),
        ],
      );
      final remote = WorkoutSnapshot(
        updatedAt: DateTime(2026, 5, 30, 9),
        lastSyncedAt: DateTime(2026, 5, 30, 9),
        sessions: [
          WorkoutSession(
            id: 'remote-old',
            date: DateTime(2026, 5, 28, 7),
            reps: 12,
            source: WorkoutSource.live,
          ),
          WorkoutSession(
            id: 'shared',
            date: DateTime(2026, 5, 29, 10),
            reps: 4,
            source: WorkoutSource.manual,
          ),
        ],
      );

      final merged = local.mergeWith(remote);

      expect(merged.sessions.map((session) => session.id), [
        'local-new',
        'shared',
        'remote-old',
      ]);
      expect(merged.dayTotals, {
        '2026-05-30': 7,
        '2026-05-29': 4,
        '2026-05-28': 12,
      });
      expect(merged.updatedAt, DateTime(2026, 5, 30, 12));
      expect(merged.lastSyncedAt, DateTime(2026, 5, 30, 9));
    });

    test('fromJson normalizes stale totals when sessions exist', () {
      final snapshot = WorkoutSnapshot.fromJson(const {
        'dayTotals': {
          '2026-05-29': 99,
          '2026-05-30': 1,
        },
        'sessions': [
          {
            'id': 'session-a',
            'date': '2026-05-30T09:00:00.000',
            'reps': 8,
            'source': 'manual',
          },
        ],
      });

      expect(snapshot.dayTotals, {'2026-05-30': 8});
    });

    test('fromJson preserves legacy day totals without sessions', () {
      final snapshot = WorkoutSnapshot.fromJson(const {
        'dayTotals': {
          '2026-05-29': 20,
          '2026-05-30': 30,
        },
      });

      expect(snapshot.dayTotals, {
        '2026-05-29': 20,
        '2026-05-30': 30,
      });
      expect(snapshot.sessions, isEmpty);
    });
  });
}
