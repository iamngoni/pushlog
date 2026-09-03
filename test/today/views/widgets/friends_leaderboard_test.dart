import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/friends/models/friend_activity.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';
import 'package:pushlog/friends/views/widgets/friend_profile_sheet.dart';
import 'package:pushlog/today/views/widgets/friends_leaderboard.dart';

class _MockProfileService extends Mock implements ProfileService {}

void main() {
  late ProfileService profileService;

  const me = UserProfile(
    uid: 'me',
    username: 'me',
    usernameLower: 'me',
  );

  setUp(() {
    profileService = _MockProfileService();
    when(
      () => profileService.loadFriends(
        me: me,
        todayCount: 7,
        weekCount: 0,
        totalAllTime: 0,
      ),
    ).thenAnswer(
      (_) async => const [
        FriendProfile(
          uid: 'me',
          label: 'me',
          username: 'me',
          todayCount: 7,
          isMe: true,
        ),
      ],
    );
    when(
      () => profileService.loadIncomingFriendRequests(ownerUid: 'me'),
    ).thenAnswer((_) async => const []);
    when(
      () => profileService.loadOutgoingFriendRequests(ownerUid: 'me'),
    ).thenAnswer((_) async => const []);
  });

  /// Renders the leaderboard and opens the friend manager sheet.
  Future<void> pumpSheet(WidgetTester tester) async {
    final cubit = FriendsCubit(profileService);
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: FriendsLeaderboard(
                theme: theme,
                me: me,
                todayCount: 7,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
  }

  testWidgets('invite opens friend sheet with visible search controls', (
    tester,
  ) async {
    final cubit = FriendsCubit(profileService);
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: FriendsLeaderboard(
                theme: theme,
                me: me,
                todayCount: 7,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('REQUESTS'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.text('Search for a friend by username.'),
      findsOneWidget,
    );
  });

  testWidgets('shows no rank while every score is zero', (tester) async {
    when(
      () => profileService.loadFriends(
        me: me,
        todayCount: 0,
        weekCount: 0,
        totalAllTime: 0,
      ),
    ).thenAnswer(
      (_) async => const [
        FriendProfile(
          uid: 'me',
          label: 'me',
          username: 'me',
          todayCount: 0,
          isMe: true,
        ),
        FriendProfile(
          uid: 'friend',
          label: 'Friend',
          username: 'friend',
          todayCount: 0,
        ),
      ],
    );
    final cubit = FriendsCubit(profileService);
    final theme = AppTheme.light();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: FriendsLeaderboard(
              theme: theme,
              me: me,
              todayCount: 0,
              showHeader: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('1'), findsNothing);
    expect(find.text('0'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('friend row exposes the requested profile drill-down', (
    tester,
  ) async {
    const friend = FriendProfile(
      uid: 'friend',
      label: 'Friend',
      username: 'friend',
      todayCount: 3,
      weekCount: 21,
      totalAllTime: 210,
      bestDay: 40,
      streak: 5,
    );
    when(
      () => profileService.loadFriends(
        me: me,
        todayCount: 7,
        weekCount: 0,
        totalAllTime: 0,
      ),
    ).thenAnswer(
      (_) async => const [
        FriendProfile(
          uid: 'me',
          label: 'me',
          username: 'me',
          todayCount: 7,
          isMe: true,
        ),
        friend,
      ],
    );
    final cubit = FriendsCubit(profileService);
    final theme = AppTheme.light();
    FriendProfile? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme.toMaterialTheme(Brightness.light),
        home: BlocProvider.value(
          value: cubit,
          child: Builder(
            builder: (context) => Scaffold(
              body: FriendsLeaderboard(
                theme: theme,
                me: me,
                todayCount: 7,
                showHeader: false,
                onEntryTap: (profile) {
                  selected = profile;
                  unawaited(
                    showFriendProfileSheet(
                      context: context,
                      theme: theme,
                      profile: profile,
                      loadActivity: () async => FriendActivity(
                        profile: profile,
                        dayTotals: const {},
                        sessions: const [],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Friend'));
    await tester.pumpAndSettle();

    expect(selected, friend);
    expect(find.text('FRIEND PROFILE'), findsOneWidget);
    expect(find.text('21 reps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoking a friend asks before it removes them', (
    tester,
  ) async {
    when(
      () => profileService.loadFriends(
        me: me,
        todayCount: 7,
        weekCount: 0,
        totalAllTime: 0,
      ),
    ).thenAnswer(
      (_) async => const [
        FriendProfile(
          uid: 'me',
          label: 'me',
          username: 'me',
          todayCount: 7,
          isMe: true,
        ),
        FriendProfile(
          uid: 'friend',
          label: 'Friend',
          username: 'friend',
          todayCount: 3,
        ),
      ],
    );
    when(
      () => profileService.revokeFriendship(
        ownerUid: 'me',
        friendUid: 'friend',
      ),
    ).thenAnswer((_) async {});

    await pumpSheet(tester);

    await tester.tap(find.text('REVOKE'));
    await tester.pumpAndSettle();

    // The question is asked, and nothing has been sent yet.
    expect(find.text('Remove @friend?'), findsOneWidget);
    verifyNever(
      () => profileService.revokeFriendship(
        ownerUid: any(named: 'ownerUid'),
        friendUid: any(named: 'friendUid'),
      ),
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Backing out leaves the friendship alone.
    verifyNever(
      () => profileService.revokeFriendship(
        ownerUid: any(named: 'ownerUid'),
        friendUid: any(named: 'friendUid'),
      ),
    );

    await tester.tap(find.text('REVOKE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    verify(
      () => profileService.revokeFriendship(
        ownerUid: 'me',
        friendUid: 'friend',
      ),
    ).called(1);
  });
}
