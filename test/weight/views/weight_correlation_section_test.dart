import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/models/weight_correlation.dart';
import 'package:pushlog/weight/views/widgets/weight_correlation_section.dart';

void main() {
  testWidgets('one weigh-in shows the not-enough caption', (tester) async {
    const correlation = WeightCorrelation(
      rows: [
        WeightWeekRow(weekStart: '2026-09-21', reps: 10, meanGrams: 70000),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: WeightCorrelationSection(
            correlation: correlation,
            unit: WeightUnit.kg,
            onLog: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Not enough weeks'), findsOneWidget);
    expect(find.textContaining('r ='), findsNothing);
  });

  testWidgets('four weeks show the association and not a cause', (
    tester,
  ) async {
    const correlation = WeightCorrelation(
      rows: [
        WeightWeekRow(weekStart: '2026-09-01', reps: 20, meanGrams: 80000),
        WeightWeekRow(
          weekStart: '2026-09-08',
          reps: 30,
          meanGrams: 79000,
          changeGrams: -1000,
        ),
        WeightWeekRow(
          weekStart: '2026-09-15',
          reps: 40,
          meanGrams: 78000,
          changeGrams: -1000,
        ),
        WeightWeekRow(
          weekStart: '2026-09-22',
          reps: 50,
          meanGrams: 77000,
          changeGrams: -1000,
        ),
      ],
      coefficient: -1,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: WeightCorrelationSection(
            correlation: correlation,
            unit: WeightUnit.kg,
            onLog: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('r = -1.00'), findsOneWidget);
    expect(find.textContaining('not a cause'), findsOneWidget);
    expect(find.text('2026-09-22'), findsOneWidget);
  });

  testWidgets('workouts without a weigh-in invite a log', (tester) async {
    const correlation = WeightCorrelation(
      rows: [WeightWeekRow(weekStart: '2026-09-21', reps: 12, meanGrams: null)],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: WeightCorrelationSection(
            correlation: correlation,
            unit: WeightUnit.kg,
            onLog: () {},
          ),
        ),
      ),
    );
    expect(find.text('Log weight'), findsOneWidget);
    expect(find.textContaining('0.0 kg'), findsNothing);
  });
}
