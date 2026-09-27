import 'package:equatable/equatable.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/weight_math.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';

class WeightWeekRow extends Equatable {
  const WeightWeekRow({
    required this.weekStart,
    required this.reps,
    required this.meanGrams,
    this.changeGrams,
  });

  final String weekStart;
  final int reps;
  final int? meanGrams;
  final int? changeGrams;

  bool get overlapping => reps > 0 && meanGrams != null;

  @override
  List<Object?> get props => [weekStart, reps, meanGrams, changeGrams];
}

class WeightCorrelation extends Equatable {
  const WeightCorrelation({required this.rows, this.coefficient});

  final List<WeightWeekRow> rows;
  final double? coefficient;

  bool get showCoefficient => coefficient != null;

  @override
  List<Object?> get props => [rows, coefficient];
}

WeightCorrelation correlateWeight({
  required List<WorkoutSession> sessions,
  required List<WeightEntry> entries,
}) {
  final repsByWeek = <String, int>{};
  for (final session in sessions) {
    final key = weekStartKey(localDayKey(session.date.toLocal()));
    repsByWeek[key] = (repsByWeek[key] ?? 0) + session.reps;
  }

  final gramsByWeek = <String, List<int>>{};
  for (final entry in entries) {
    final key = weekStartKey(entry.recordedOn);
    gramsByWeek.putIfAbsent(key, () => []).add(entry.weightGrams);
  }

  final weeks = {...repsByWeek.keys, ...gramsByWeek.keys}.toList()..sort();
  final rows = <WeightWeekRow>[];
  int? previousMean;
  for (final week in weeks) {
    final samples = gramsByWeek[week];
    final mean = samples == null || samples.isEmpty
        ? null
        : (samples.reduce((a, b) => a + b) / samples.length).round();
    final change = mean != null && previousMean != null
        ? mean - previousMean
        : null;
    if (mean != null) previousMean = mean;
    rows.add(
      WeightWeekRow(
        weekStart: week,
        reps: repsByWeek[week] ?? 0,
        meanGrams: mean,
        changeGrams: change,
      ),
    );
  }

  final overlapping = rows.where((row) => row.overlapping).toList();
  double? coefficient;
  if (overlapping.length >= 4) {
    coefficient = pearson(
      overlapping.map((row) => row.reps.toDouble()).toList(),
      overlapping.map((row) => row.meanGrams!.toDouble()).toList(),
    );
  }
  return WeightCorrelation(rows: rows, coefficient: coefficient);
}
