import 'dart:math';

import 'package:pushlog/weight/models/data/weight_settings.dart';

const int gramsPerKilogram = 1000;
const double gramsPerPound = 453.59237;

int kilogramsToGrams(double kilograms) =>
    (kilograms * gramsPerKilogram).round();

int poundsToGrams(double pounds) => (pounds * gramsPerPound).round();

int displayToGrams(double value, WeightUnit unit) {
  return switch (unit) {
    WeightUnit.kg => kilogramsToGrams(value),
    WeightUnit.lb => poundsToGrams(value),
  };
}

double gramsToDisplay(int grams, WeightUnit unit) {
  final raw = switch (unit) {
    WeightUnit.kg => grams / gramsPerKilogram,
    WeightUnit.lb => grams / gramsPerPound,
  };
  return (raw * 10).round() / 10;
}

String formatWeight(int grams, WeightUnit unit) {
  final value = gramsToDisplay(grams, unit);
  final label = unit == WeightUnit.kg ? 'kg' : 'lb';
  return '${value.toStringAsFixed(1)} $label';
}

String formatSignedChange(int grams, WeightUnit unit) {
  final value = gramsToDisplay(grams.abs(), unit);
  final sign = grams < 0
      ? '−'
      : grams > 0
      ? '+'
      : '';
  final label = unit == WeightUnit.kg ? 'kg' : 'lb';
  return '$sign${value.toStringAsFixed(1)} $label';
}

String localDayKey(DateTime local) {
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String weekStartKey(String dayKey) {
  final parts = dayKey.split('-');
  if (parts.length != 3) return dayKey;
  final date = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return localDayKey(monday);
}

double? pearson(List<double> xs, List<double> ys) {
  if (xs.length != ys.length || xs.length < 2) return null;
  final count = xs.length;
  final meanX = xs.reduce((a, b) => a + b) / count;
  final meanY = ys.reduce((a, b) => a + b) / count;
  var numerator = 0.0;
  var denomX = 0.0;
  var denomY = 0.0;
  for (var i = 0; i < count; i++) {
    final dx = xs[i] - meanX;
    final dy = ys[i] - meanY;
    numerator += dx * dy;
    denomX += dx * dx;
    denomY += dy * dy;
  }
  if (denomX == 0 || denomY == 0) return null;
  return numerator / sqrt(denomX * denomY);
}
