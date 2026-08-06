import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/models/friend_request.dart';

part 'friends_state.dart';

class FriendsCubit extends Cubit<FriendsState> {
  FriendsCubit(this._profileService) : super(const FriendsState());

  final ProfileService _profileService;

  Future<void> load({
    required UserProfile me,
    required int todayCount,
    int? weekCount,
    int? totalAllTime,
  }) async {
    emit(state.copyWith(isLoading: true));
    try {
      final leaderboard = await _profileService.loadFriends(
        me: me,
        todayCount: todayCount,
        weekCount: weekCount ?? me.weekCount,
        totalAllTime: totalAllTime ?? me.totalAllTime,
      );
      final incomingRequests = await _profileService.loadIncomingFriendRequests(
        ownerUid: me.uid,
      );
      final outgoingRequests = await _profileService.loadOutgoingFriendRequests(
        ownerUid: me.uid,
      );
      final friendIds = leaderboard
          .where((entry) => !entry.isMe)
          .map((entry) => entry.uid)
          .toSet();
      final openIncomingRequests = incomingRequests
          .where((request) => !friendIds.contains(request.uid))
          .toList();
      final openOutgoingRequests = outgoingRequests
          .where((request) => !friendIds.contains(request.uid))
          .toList();
      emit(
        state.copyWith(
          isLoading: false,
          leaderboard: leaderboard,
          friendIds: friendIds,
          incomingRequests: openIncomingRequests,
          outgoingRequests: openOutgoingRequests,
          incomingRequestIds: openIncomingRequests
              .map((request) => request.uid)
              .toSet(),
          outgoingRequestIds: openOutgoingRequests
              .map((request) => request.uid)
              .toSet(),
        ),
      );
    } on Exception catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: error.toString(),
        ),
      );
    }
  }

  Future<void> search({
    required UserProfile me,
    required String query,
  }) async {
    emit(
      state.copyWith(
        searchQuery: query,
        isSearching: query.trim().length >= 2,
      ),
    );
    if (query.trim().length < 2) {
      emit(
        state.copyWith(
          isSearching: false,
          searchResults: const [],
        ),
      );
      return;
    }

    try {
      final results = await _profileService.searchUsersByUsername(
        query,
        excludeUid: me.uid,
      );
      emit(
        state.copyWith(
          isSearching: false,
          searchResults: results,
        ),
      );
    } on Exception catch (error) {
      emit(
        state.copyWith(
          isSearching: false,
          error: error.toString(),
        ),
      );
    }
  }

  Future<void> sendFriendRequest({
    required UserProfile me,
    required int todayCount,
    required UserProfile receiver,
  }) async {
    await _profileService.sendFriendRequest(
      requester: me,
      receiver: receiver,
    );
    await search(me: me, query: state.searchQuery);
    await load(me: me, todayCount: todayCount);
  }

  Future<void> acceptFriendRequest({
    required UserProfile me,
    required int todayCount,
    required FriendRequest requester,
  }) async {
    await _profileService.acceptFriendRequest(
      receiver: me,
      requester: requester,
    );
    await load(me: me, todayCount: todayCount);
  }

  Future<void> declineFriendRequest({
    required UserProfile me,
    required int todayCount,
    required String requesterUid,
  }) async {
    await _profileService.declineFriendRequest(
      ownerUid: me.uid,
      requesterUid: requesterUid,
    );
    await load(me: me, todayCount: todayCount);
  }

  Future<void> cancelFriendRequest({
    required UserProfile me,
    required int todayCount,
    required String receiverUid,
  }) async {
    await _profileService.cancelFriendRequest(
      ownerUid: me.uid,
      receiverUid: receiverUid,
    );
    await search(me: me, query: state.searchQuery);
    await load(me: me, todayCount: todayCount);
  }

  Future<void> revokeFriendship({
    required UserProfile me,
    required int todayCount,
    required String friendUid,
  }) async {
    await _profileService.revokeFriendship(
      ownerUid: me.uid,
      friendUid: friendUid,
    );
    await load(me: me, todayCount: todayCount);
  }

  Future<void> removeFriend({
    required UserProfile me,
    required int todayCount,
    required String friendUid,
  }) async {
    await revokeFriendship(
      me: me,
      todayCount: todayCount,
      friendUid: friendUid,
    );
  }
}
