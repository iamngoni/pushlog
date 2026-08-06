import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/models/friend_request.dart';
import 'package:pushlog/friends/state/friends_cubit.dart';

class _MockProfileService extends Mock implements ProfileService {}

void main() {
  late ProfileService profileService;

  const me = UserProfile(
    uid: 'me',
    username: 'me',
    usernameLower: 'me',
  );
  const friend = UserProfile(
    uid: 'friend',
    username: 'friend',
    usernameLower: 'friend',
    todayCount: 30,
  );
  const friendEntry = FriendProfile(
    uid: 'friend',
    label: 'friend',
    username: 'friend',
    todayCount: 30,
  );
  const incomingRequest = FriendRequest(
    uid: 'friend',
    username: 'friend',
    label: 'friend',
  );
  const outgoingRequest = FriendRequest(
    uid: 'other',
    username: 'other',
    label: 'other',
  );

  setUp(() {
    profileService = _MockProfileService();
  });

  blocTest<FriendsCubit, FriendsState>(
    'filters stale requests from accepted friends',
    build: () {
      when(
        () => profileService.loadFriends(
          me: me,
          todayCount: 12,
          weekCount: 0,
          totalAllTime: 0,
        ),
      ).thenAnswer(
        (_) async => const [
          FriendProfile(
            uid: 'me',
            label: 'me',
            username: 'me',
            todayCount: 12,
            isMe: true,
          ),
          friendEntry,
        ],
      );
      when(
        () => profileService.loadIncomingFriendRequests(ownerUid: 'me'),
      ).thenAnswer((_) async => const [incomingRequest]);
      when(
        () => profileService.loadOutgoingFriendRequests(ownerUid: 'me'),
      ).thenAnswer((_) async => const [outgoingRequest]);
      return FriendsCubit(profileService);
    },
    act: (cubit) => cubit.load(me: me, todayCount: 12),
    expect: () => [
      const FriendsState(isLoading: true),
      const FriendsState(
        leaderboard: [
          FriendProfile(
            uid: 'me',
            label: 'me',
            username: 'me',
            todayCount: 12,
            isMe: true,
          ),
          friendEntry,
        ],
        friendIds: {'friend'},
        outgoingRequests: [outgoingRequest],
        outgoingRequestIds: {'other'},
      ),
    ],
  );

  blocTest<FriendsCubit, FriendsState>(
    'searches public profiles by username',
    build: () {
      when(
        () => profileService.searchUsersByUsername(
          'fri',
          excludeUid: 'me',
        ),
      ).thenAnswer((_) async => const [friend]);
      return FriendsCubit(profileService);
    },
    act: (cubit) => cubit.search(me: me, query: 'fri'),
    expect: () => [
      const FriendsState(searchQuery: 'fri', isSearching: true),
      const FriendsState(searchQuery: 'fri', searchResults: [friend]),
    ],
  );

  blocTest<FriendsCubit, FriendsState>(
    'sending a friend request refreshes search and request state',
    build: () {
      when(
        () => profileService.sendFriendRequest(requester: me, receiver: friend),
      ).thenAnswer((_) async {});
      when(
        () => profileService.searchUsersByUsername(
          'fri',
          excludeUid: 'me',
        ),
      ).thenAnswer((_) async => const [friend]);
      when(
        () => profileService.loadFriends(
          me: me,
          todayCount: 12,
          weekCount: 0,
          totalAllTime: 0,
        ),
      ).thenAnswer((_) async => const [friendEntry]);
      when(
        () => profileService.loadIncomingFriendRequests(ownerUid: 'me'),
      ).thenAnswer((_) async => const []);
      when(
        () => profileService.loadOutgoingFriendRequests(ownerUid: 'me'),
      ).thenAnswer((_) async => const [incomingRequest]);
      return FriendsCubit(profileService);
    },
    seed: () => const FriendsState(searchQuery: 'fri'),
    act: (cubit) => cubit.sendFriendRequest(
      me: me,
      todayCount: 12,
      receiver: friend,
    ),
    verify: (_) {
      verify(
        () => profileService.sendFriendRequest(requester: me, receiver: friend),
      ).called(1);
      verify(
        () => profileService.loadFriends(
          me: me,
          todayCount: 12,
          weekCount: 0,
          totalAllTime: 0,
        ),
      ).called(1);
    },
  );

  blocTest<FriendsCubit, FriendsState>(
    'accepting a request refreshes reciprocal visibility',
    build: () {
      when(
        () => profileService.acceptFriendRequest(
          receiver: me,
          requester: incomingRequest,
        ),
      ).thenAnswer((_) async {});
      when(
        () => profileService.loadFriends(
          me: me,
          todayCount: 12,
          weekCount: 0,
          totalAllTime: 0,
        ),
      ).thenAnswer((_) async => const [friendEntry]);
      when(
        () => profileService.loadIncomingFriendRequests(ownerUid: 'me'),
      ).thenAnswer((_) async => const []);
      when(
        () => profileService.loadOutgoingFriendRequests(ownerUid: 'me'),
      ).thenAnswer((_) async => const []);
      return FriendsCubit(profileService);
    },
    act: (cubit) => cubit.acceptFriendRequest(
      me: me,
      todayCount: 12,
      requester: incomingRequest,
    ),
    verify: (_) {
      verify(
        () => profileService.acceptFriendRequest(
          receiver: me,
          requester: incomingRequest,
        ),
      ).called(1);
    },
  );

  blocTest<FriendsCubit, FriendsState>(
    'revoking a friendship removes both sides and refreshes visibility',
    build: () {
      when(
        () => profileService.revokeFriendship(
          ownerUid: 'me',
          friendUid: 'friend',
        ),
      ).thenAnswer((_) async {});
      when(
        () => profileService.loadFriends(
          me: me,
          todayCount: 12,
          weekCount: 0,
          totalAllTime: 0,
        ),
      ).thenAnswer((_) async => const []);
      when(
        () => profileService.loadIncomingFriendRequests(ownerUid: 'me'),
      ).thenAnswer((_) async => const []);
      when(
        () => profileService.loadOutgoingFriendRequests(ownerUid: 'me'),
      ).thenAnswer((_) async => const []);
      return FriendsCubit(profileService);
    },
    act: (cubit) => cubit.revokeFriendship(
      me: me,
      todayCount: 12,
      friendUid: 'friend',
    ),
    verify: (_) {
      verify(
        () => profileService.revokeFriendship(
          ownerUid: 'me',
          friendUid: 'friend',
        ),
      ).called(1);
    },
  );
}
