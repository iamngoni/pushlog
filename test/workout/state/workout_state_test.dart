import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

void main() {
  test('week count includes Monday through today only', () {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day).subtract(
      Duration(days: today.weekday - 1),
    );
    final totals = <String, int>{};
    var expected = 0;
    for (var offset = 0; offset < today.weekday; offset++) {
      final reps = offset + 1;
      totals[WorkoutBloc.dayKey(monday.add(Duration(days: offset)))] = reps;
      expected += reps;
    }
    if (today.weekday < DateTime.sunday) {
      totals[WorkoutBloc.dayKey(monday.add(const Duration(days: 6)))] = 99;
    }

    final state = WorkoutLoaded(
      dayTotals: totals,
      sessions: const [],
      preferences: const WorkoutPreferences(),
    );

    expect(state.weekCount, expected);
  });
}
