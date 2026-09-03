import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/friends/models/friend_activity.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/views/widgets/friend_profile_sheet.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';

void main() {
  testWidgets('friend profile shows full recorded session details', (
    tester,
  ) async {
    final theme = AppTheme.light();
    const profile = FriendProfile(
      uid: 'friend',
      label: 'Haniel Test',
      username: 'haniel',
      todayCount: 3,
      weekCount: 21,
      totalAllTime: 210,
      bestDay: 40,
      streak: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: Scaffold(
          body: FriendProfileSheet(
            profile: profile,
            theme: theme,
            loadActivity: () async => FriendActivity(
              profile: profile,
              dayTotals: const {'2026-08-06': 3},
              sessions: [
                WorkoutSession(
                  id: 'session-1',
                  date: DateTime(2026, 8, 6, 17, 38),
                  reps: 3,
                  source: WorkoutSource.live,
                  duration: const Duration(seconds: 28),
                  averageRepDuration: const Duration(seconds: 9),
                  manualAdjustments: 1,
                  effortScore: 8,
                  latestHeartRate: 142.5,
                  activeCalories: 18.75,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('FRIEND PROFILE'), findsOneWidget);
    expect(find.text('Haniel Test'), findsOneWidget);
    expect(find.text('@haniel'), findsOneWidget);
    expect(find.text('3 reps'), findsOneWidget);
    expect(find.text('21 reps'), findsOneWidget);
    expect(find.text('210 reps'), findsOneWidget);
    expect(find.text('40 reps'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
    expect(
      find.text('Workout details are shared only between accepted friends.'),
      findsOneWidget,
    );
    expect(find.text('SESSION HISTORY'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('LIVE SESSION'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('LIVE SESSION'), findsOneWidget);
    expect(find.text('6 Aug 2026 · 17:38'), findsOneWidget);
    expect(find.text('00:00:28'), findsOneWidget);
    expect(find.text('8/10 · Hard'), findsOneWidget);
    expect(find.text('143 BPM'), findsOneWidget);
    expect(find.text('18.8 kcal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
