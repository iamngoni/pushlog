import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/weight_correlation.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';

WorkoutSession session(String day, int reps) {
  return WorkoutSession(
    id: day,
    date: DateTime.parse('${day}T12:00:00'),
    reps: reps,
    source: WorkoutSource.manual,
  );
}

WeightEntry weigh(String day, int grams) {
  return WeightEntry(
    recordedOn: day,
    weightGrams: grams,
    updatedAt: '${day}T12:00:00Z',
  );
}

void main() {
  test(
    'four overlapping weeks with rising reps and falling weight are negative',
    () {
      final result = correlateWeight(
        sessions: [
          session('2026-09-01', 20),
          session('2026-09-08', 30),
          session('2026-09-15', 40),
          session('2026-09-22', 50),
        ],
        entries: [
          weigh('2026-09-01', 80000),
          weigh('2026-09-08', 79000),
          weigh('2026-09-15', 78000),
          weigh('2026-09-22', 77000),
        ],
      );
      expect(result.showCoefficient, isTrue);
      expect(result.coefficient, lessThan(0));
      expect(result.coefficient!.toStringAsFixed(3), '-1.000');
    },
  );

  test('three overlapping weeks hide the coefficient and keep the rows', () {
    final result = correlateWeight(
      sessions: [
        session('2026-09-01', 10),
        session('2026-09-08', 10),
        session('2026-09-15', 10),
      ],
      entries: [
        weigh('2026-09-01', 70000),
        weigh('2026-09-08', 70000),
        weigh('2026-09-15', 70000),
      ],
    );
    expect(result.showCoefficient, isFalse);
    expect(result.rows, hasLength(3));
  });

  test('a weigh-in week with zero reps is listed and excluded from r', () {
    final result = correlateWeight(
      sessions: [
        session('2026-09-08', 10),
        session('2026-09-15', 20),
        session('2026-09-22', 30),
        session('2026-09-29', 40),
      ],
      entries: [
        weigh('2026-09-01', 70000),
        weigh('2026-09-08', 69000),
        weigh('2026-09-15', 68000),
        weigh('2026-09-22', 67000),
        weigh('2026-09-29', 66000),
      ],
    );
    expect(result.rows.first.reps, 0);
    expect(result.showCoefficient, isTrue);
  });

  test('no weigh-ins returns an empty row list when there are no sessions', () {
    final result = correlateWeight(sessions: const [], entries: const []);
    expect(result.rows, isEmpty);
    expect(result.showCoefficient, isFalse);
  });
}
