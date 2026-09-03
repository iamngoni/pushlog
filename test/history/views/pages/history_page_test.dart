import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/history/views/pages/history_page.dart';
import 'package:pushlog/history/views/widgets/history_entry_row.dart';
import 'package:pushlog/workout/models/data/history_entry.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class _MockWorkoutBloc extends MockBloc<WorkoutEvent, WorkoutState>
    implements WorkoutBloc {}

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
    final sessions = [
      WorkoutSession(
        id: 'live-1',
        date: DateTime(2026, 8, 6, 17, 38),
        reps: 70,
        source: WorkoutSource.live,
        duration: const Duration(minutes: 3, seconds: 20),
        averageRepDuration: const Duration(seconds: 2),
        manualAdjustments: 3,
        effortScore: 8,
        latestHeartRate: 142.5,
        activeCalories: 18.75,
      ),
    ];

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
                builder: (_) => DayDetailSheet(
                  entry: entry,
                  sessions: sessions,
                  theme: theme,
                ),
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
    expect(find.text('TOTAL REPS'), findsOneWidget);
    expect(find.text('LIVE SESSION'), findsOneWidget);
    expect(find.text('17:38'), findsOneWidget);
    expect(find.text('00:03:20'), findsOneWidget);
    expect(find.text('8/10 · Hard'), findsOneWidget);
    expect(find.text('143 BPM'), findsOneWidget);
    expect(find.text('18.8 kcal'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a history day opens its recorded live session', (
    tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 17, 38);
    final session = WorkoutSession(
      id: 'live-today',
      date: day,
      reps: 10,
      source: WorkoutSource.live,
      duration: const Duration(seconds: 28),
      effortScore: 7,
      latestHeartRate: 130,
      activeCalories: 4.5,
    );
    final state = WorkoutLoaded(
      dayTotals: {WorkoutBloc.dayKey(day): 10},
      sessions: [session],
      preferences: const WorkoutPreferences(),
    );
    final bloc = _MockWorkoutBloc();
    whenListen(bloc, const Stream<WorkoutState>.empty(), initialState: state);
    addTearDown(bloc.close);
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: BlocProvider<WorkoutBloc>.value(
          value: bloc,
          child: const Scaffold(body: HistoryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HistoryEntryRow));
    await tester.pumpAndSettle();

    expect(find.text('LIVE SESSION'), findsOneWidget);
    expect(find.text('00:00:28'), findsOneWidget);
    expect(find.text('7/10 · Hard'), findsOneWidget);
    expect(find.text('130 BPM'), findsOneWidget);
    expect(find.text('4.5 kcal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
