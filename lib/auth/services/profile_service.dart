import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/core/services/pushlog_api_client.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/models/friend_request.dart';

class UsernameClaimResult {
  const UsernameClaimResult._({
    required this.success,
    this.message,
  });

  const UsernameClaimResult.success() : this._(success: true);

  const UsernameClaimResult.failure(String message)
    : this._(success: false, message: message);

  final bool success;
  final String? message;
}

class ProfileService {
  ProfileService(this._api);

  final PushlogApiClient _api;
  final StreamController<UserProfile?> _profileUpdates =
      StreamController<UserProfile?>.broadcast();
  UserProfile? _cachedProfile;

  Stream<UserProfile?> watchProfile(String uid) async* {
    final cached = _cachedProfile;
    if (cached != null && cached.uid == uid) {
      yield cached;
    } else {
      yield await _loadOwnProfile();
    }
    yield* _profileUpdates.stream.where(
      (profile) => profile == null || profile.uid == uid,
    );
  }

  Future<void> ensureProfileShell(User user) async {
    final response = await _api.put('/v1/profile');
    _cacheProfile(_profileFromResponse(response));
  }

  Future<UsernameClaimResult> claimUsername({
    required User user,
    required String username,
  }) async {
    final normalized = normalizeUsername(username);
    if (normalized == null) {
      return const UsernameClaimResult.failure(
        'Use 3-20 letters, numbers, or underscores.',
      );
    }

    try {
      final response = await _api.put(
        '/v1/profile/username',
        body: {'username': username.trim()},
      );
      _cacheProfile(_profileFromResponse(response));
      return const UsernameClaimResult.success();
    } on PushlogApiException catch (error) {
      if (error.code == 'username_taken' || error.code == 'invalid_username') {
        return UsernameClaimResult.failure(error.message);
      }
      return const UsernameClaimResult.failure(
        'Unable to claim username right now.',
      );
    }
  }

  Future<List<UserProfile>> searchUsersByUsername(
    String query, {
    required String excludeUid,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];
    final response = await _api.get(
      '/v1/users/search',
      query: {'q': normalized},
    );
    return _profileList(
      response['profiles'],
    ).where((profile) => profile.uid != excludeUid).toList();
  }

  Future<List<FriendProfile>> loadFriends({
    required UserProfile me,
    required int todayCount,
    required int weekCount,
    required int totalAllTime,
  }) async {
    final now = DateTime.now();
    final response = await _api.get(
      '/v1/friends',
      query: {
        'dayKey': _dayKey(now),
        'weekKey': _dayKey(
          DateTime(now.year, now.month, now.day).subtract(
            Duration(days: now.weekday - 1),
          ),
        ),
      },
    );
    final entries =
        <FriendProfile>[
          FriendProfile.fromUserProfile(
            me,
            isMe: true,
            todayCount: todayCount,
            weekCount: weekCount,
            totalAllTime: totalAllTime,
          ),
          ..._profileList(response['friends']).map(
            FriendProfile.fromUserProfile,
          ),
        ]..sort(
          (left, right) => right.todayCount.compareTo(left.todayCount),
        );
    return entries;
  }

  Future<List<FriendRequest>> loadIncomingFriendRequests({
    required String ownerUid,
  }) async {
    return _loadRequests('incoming');
  }

  Future<List<FriendRequest>> loadOutgoingFriendRequests({
    required String ownerUid,
  }) async {
    return _loadRequests('outgoing');
  }

  Future<void> sendFriendRequest({
    required UserProfile requester,
    required UserProfile receiver,
  }) async {
    if (requester.uid == receiver.uid) return;
    await _api.post(
      '/v1/friend-requests',
      body: {'receiverUid': receiver.uid},
    );
  }

  Future<void> acceptFriendRequest({
    required UserProfile receiver,
    required FriendRequest requester,
  }) async {
    if (receiver.uid == requester.uid) return;
    await _api.post(
      '/v1/friend-requests/accept',
      body: {'requesterUid': requester.uid},
    );
  }

  Future<void> declineFriendRequest({
    required String ownerUid,
    required String requesterUid,
  }) async {
    await _api.post(
      '/v1/friend-requests/decline',
      body: {'requesterUid': requesterUid},
    );
  }

  Future<void> cancelFriendRequest({
    required String ownerUid,
    required String receiverUid,
  }) async {
    await _api.post(
      '/v1/friend-requests/cancel',
      body: {'receiverUid': receiverUid},
    );
  }

  Future<void> revokeFriendship({
    required String ownerUid,
    required String friendUid,
  }) async {
    await _api.delete('/v1/friends', body: {'friendUid': friendUid});
  }

  Future<void> removeFriend({
    required String ownerUid,
    required String friendUid,
  }) async {
    await revokeFriendship(ownerUid: ownerUid, friendUid: friendUid);
  }

  Future<void> reportAndBlockUser({required String reportedUid}) async {
    await _api.post(
      '/v1/reports',
      body: {
        'reportedUid': reportedUid,
        'reason': 'safety_concern',
      },
    );
  }

  Future<void> deleteAccountData({required String uid}) async {
    await _api.delete('/v1/account');
    _cachedProfile = null;
    _profileUpdates.add(null);
  }

  static String? normalizeUsername(String input) {
    final lowered = input.trim().toLowerCase();
    return RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(lowered) ? lowered : null;
  }

  Future<UserProfile> _loadOwnProfile() async {
    final response = await _api.get('/v1/profile');
    final profile = _profileFromResponse(response);
    _cacheProfile(profile);
    return profile;
  }

  Future<List<FriendRequest>> _loadRequests(String direction) async {
    final response = await _api.get(
      '/v1/friend-requests',
      query: {'direction': direction},
    );
    final requests = response['requests'];
    if (requests is! List) return const [];
    return requests
        .whereType<Map<String, dynamic>>()
        .map(FriendRequest.fromJson)
        .toList();
  }

  UserProfile _profileFromResponse(Map<String, dynamic> response) {
    final value = response['profile'];
    if (value is! Map<String, dynamic>) {
      throw const PushlogApiException(
        statusCode: 502,
        code: 'invalid_response',
        message: 'Pushlog returned an invalid profile.',
      );
    }
    return UserProfile.fromJson(value);
  }

  List<UserProfile> _profileList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(UserProfile.fromJson)
        .toList();
  }

  void _cacheProfile(UserProfile profile) {
    _cachedProfile = profile;
    _profileUpdates.add(profile);
  }

  String _dayKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
