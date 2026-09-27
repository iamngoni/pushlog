import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/views/widgets/weight_friends_board.dart';

void main() {
  testWidgets('friend row without latest weight hides the number', (
    tester,
  ) async {
    const entry = FriendWeighIn(
      uid: 'a',
      displayName: 'Ana',
      goal: 'lose',
      signedChangeGrams: -400,
      weighInCount: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: const Scaffold(
          body: WeightFriendsBoard(
            entries: [entry],
            unit: WeightUnit.kg,
            error: null,
          ),
        ),
      ),
    );
    expect(find.textContaining('Ana'), findsOneWidget);
    expect(find.textContaining('kg'), findsOneWidget);
    expect(find.textContaining('70.0'), findsNothing);
  });

  testWidgets('opted-in friends render in the given order', (tester) async {
    const entries = [
      FriendWeighIn(
        uid: 'b',
        displayName: 'Bo',
        goal: 'maintain',
        signedChangeGrams: 100,
        weighInCount: 2,
      ),
      FriendWeighIn(
        uid: 'a',
        displayName: 'Ana',
        goal: 'maintain',
        signedChangeGrams: -400,
        weighInCount: 2,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: const Scaffold(
          body: WeightFriendsBoard(
            entries: entries,
            unit: WeightUnit.kg,
            error: null,
          ),
        ),
      ),
    );
    expect(find.textContaining('Bo'), findsOneWidget);
    expect(find.textContaining('Ana'), findsOneWidget);
    final bo = tester.getTopLeft(find.textContaining('Bo'));
    final ana = tester.getTopLeft(find.textContaining('Ana'));
    expect(bo.dy, lessThan(ana.dy));
  });

  testWidgets('board failure keeps the section error and no zero row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().toMaterialTheme(Brightness.light),
        home: const Scaffold(
          body: WeightFriendsBoard(
            entries: [],
            unit: WeightUnit.kg,
            error: 'down',
          ),
        ),
      ),
    );
    expect(find.textContaining('Could not load weigh-ins'), findsOneWidget);
    expect(find.textContaining('0.0'), findsNothing);
  });
}
