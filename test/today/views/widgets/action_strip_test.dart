import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/today/views/widgets/action_strip.dart';

void main() {
  late List<int> logged;

  setUp(() => logged = <int>[]);

  Future<void> pumpStrip(WidgetTester tester) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: ActionStrip(
            theme: theme,
            suggestedSet: 10,
            onAddReps: logged.add,
          ),
        ),
      ),
    );
  }

  /// Presses a cell, holds for [hold], then lifts.
  Future<void> holdCell(
    WidgetTester tester,
    String label,
    Duration hold,
  ) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(label)),
    );
    await tester.pump();
    await tester.pump(hold);
    await gesture.up();
    await tester.pump();
  }

  testWidgets('a quick tap logs nothing', (tester) async {
    await pumpStrip(tester);

    await tester.tap(find.text('+1'));
    await tester.pump();

    // The whole point: a brush against the strip must not write reps.
    expect(logged, isEmpty);
  });

  testWidgets('releasing before the hold completes logs nothing', (
    tester,
  ) async {
    await pumpStrip(tester);

    await holdCell(
      tester,
      '+1',
      ActionCell.holdDuration - const Duration(milliseconds: 200),
    );

    expect(logged, isEmpty);
  });

  testWidgets('holding for the full duration logs once', (tester) async {
    await pumpStrip(tester);

    await holdCell(
      tester,
      '+10',
      ActionCell.holdDuration + const Duration(milliseconds: 100),
    );

    expect(logged, [10]);
  });

  testWidgets('holding past the duration does not log twice', (tester) async {
    await pumpStrip(tester);

    await holdCell(
      tester,
      '+25',
      ActionCell.holdDuration * 3,
    );

    // One sustained press is one log, however long it is held.
    expect(logged, [25]);
  });

  testWidgets('an abandoned hold does not arm the next one', (tester) async {
    await pumpStrip(tester);

    await holdCell(tester, '+1', const Duration(milliseconds: 500));
    expect(logged, isEmpty);

    // The second hold must run the full duration on its own, not inherit
    // progress from the one before it.
    await holdCell(tester, '+1', const Duration(milliseconds: 500));
    expect(logged, isEmpty);

    await holdCell(
      tester,
      '+1',
      ActionCell.holdDuration + const Duration(milliseconds: 100),
    );
    expect(logged, [1]);
  });

  testWidgets('each cell logs its own amount', (tester) async {
    await pumpStrip(tester);
    final full = ActionCell.holdDuration + const Duration(milliseconds: 100);

    await holdCell(tester, '+1', full);
    await holdCell(tester, '+10', full);
    await holdCell(tester, '+25', full);

    expect(logged, [1, 10, 25]);
  });

  testWidgets('exposes a hold hint to assistive tech', (tester) async {
    await pumpStrip(tester);

    final node = tester.getSemantics(find.bySemanticsLabel('Log 10 reps'));
    expect(node.hint, 'Hold to log');
  });
}
