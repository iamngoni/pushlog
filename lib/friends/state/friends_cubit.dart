import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/auth/services/profile_service.dart';
import 'package:pushlog/friends/models/friend_profile.dart';

part 'friends_state.dart';

class FriendsCubit extends Cubit<FriendsState> {
  FriendsCubit(this._profileService)
      : super(const FriendsState());

  final ProfileService _profileService;

  Future<void> load({
    required UserProfile me,
    required int todayCount,
  }) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final leaderboard =
          await _profileService.loadFriends(
        me: me,
        todayCount: todayCount,
      );
      emit(
        state.copyWith(
          isLoading: false,
          leaderboard: leaderboard,
          friendIds: leaderboard
              .where((entry) => !entry.isMe)
              .map((entry) => entry.uid)
              .toSet(),
        ),
      );
    } catch (error) {
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
        error: null,
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
      final results =
          await _profileService.searchUsersByUsername(
        query,
        excludeUid: me.uid,
      );
      emit(
        state.copyWith(
          isSearching: false,
          searchResults: results,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSearching: false,
          error: error.toString(),
        ),
      );
    }
  }

  Future<void> addFriend({
    required UserProfile me,
    required int todayCount,
    required UserProfile friend,
  }) async {
    await _profileService.addFriend(
      ownerUid: me.uid,
      friend: friend,
    );
    await search(me: me, query: state.searchQuery);
    await load(me: me, todayCount: todayCount);
  }

  Future<void> removeFriend({
    required UserProfile me,
    required int todayCount,
    required String friendUid,
  }) async {
    await _profileService.removeFriend(
      ownerUid: me.uid,
      friendUid: friendUid,
    );
    await load(me: me, todayCount: todayCount);
  }
}
