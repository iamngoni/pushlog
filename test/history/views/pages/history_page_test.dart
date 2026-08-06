import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/history/views/pages/history_page.dart';
import 'package:pushlog/workout/models/data/history_entry.dart';

void main() {
  testWidgets('day detail sheet uses the available modal width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final theme = AppTheme.light();
    final entry = HistoryEntry(
      date: DateTime(2026, 8, 6),
      count: 70,
      isToday: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: theme.background,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.top(AppRadius.xxl),
                ),
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => DayDetailSheet(entry: entry, theme: theme),
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    final sheet = find.byType(DraggableScrollableSheet);
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet).width, 430);
    expect(find.text('70'), findsOneWidget);
    expect(find.text('REPS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
