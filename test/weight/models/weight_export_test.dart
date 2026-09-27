import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/weight/models/weight_export.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';

void main() {
  test('weight joins the export without moving the workout keys', () {
    final snapshot = WorkoutSnapshot(
      dayTotals: const {'2026-09-27': 20},
      sessions: [
        WorkoutSession(
          id: 'a',
          date: DateTime.utc(2026, 9, 27, 8),
          reps: 20,
          source: WorkoutSource.manual,
        ),
      ],
    );
    final workoutJson = snapshot.toPrettyJson();

    final exported = mergeWeightExport(workoutJson, [
      {'recordedOn': '2026-09-27', 'weightGrams': 72500},
    ]);
    final merged = jsonDecode(exported) as Map<String, dynamic>;

    final original = jsonDecode(workoutJson) as Map<String, dynamic>;
    for (final key in original.keys) {
      expect(merged[key], original[key], reason: key);
    }
    expect(merged['sessions'], hasLength(1));
    expect(merged['weightEntries'], [
      {'recordedOn': '2026-09-27', 'weightGrams': 72500},
    ]);
  });
}
