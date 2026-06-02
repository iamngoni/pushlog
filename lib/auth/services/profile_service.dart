import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/friends/models/friend_request.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';

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

class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

class ProfileService {
  ProfileService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _publicProfiles =>
      _firestore.collection('publicProfiles');

  CollectionReference<Map<String, dynamic>> get _friendStats =>
      _firestore.collection('friendStats');

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _firestore.collection('usernames');

  Stream<UserProfile?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      return UserProfile.fromJson(data);
    });
  }

  Future<void> ensureProfileShell(User user) async {
    final now = DateTime.now().toIso8601String();
    final userRef = _users.doc(user.uid);
    final publicProfileRef = _publicProfiles.doc(user.uid);
    final userSnapshot = await userRef.get();
    final publicSnapshot = await publicProfileRef.get();
    final privateProfile = userSnapshot.data();
    final publicProfile = publicSnapshot.data();
    final previousUsername =
        privateProfile?['username'] as String? ??
        publicProfile?['username'] as String?;
    final previousUsernameLower =
        privateProfile?['usernameLower'] as String? ??
        publicProfile?['usernameLower'] as String? ??
        (previousUsername == null ? null : normalizeUsername(previousUsername));
    final createdAt =
        privateProfile?['createdAt'] as String? ??
        publicProfile?['createdAt'] as String? ??
        now;
    final privateData = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'createdAt': createdAt,
      'updatedAt': now,
    };
    if (previousUsername != null) {
      privateData['username'] = previousUsername;
    }
    if (previousUsernameLower != null) {
      privateData['usernameLower'] = previousUsernameLower;
    }
    final publicData = _publicProfileData(
      user: user,
      fallbackUsername: previousUsername,
      usernameLower: previousUsernameLower,
      createdAt: createdAt,
      updatedAt: now,
    );

    final batch = _firestore.batch()
      ..set(userRef, privateData, SetOptions(merge: true))
      ..set(publicProfileRef, publicData);
    await batch.commit();
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

    final userRef = _users.doc(user.uid);
    final publicProfileRef = _publicProfiles.doc(user.uid);
    final usernameRef = _usernames.doc(normalized);

    try {
      await _firestore.runTransaction((transaction) async {
        final existingUsername = await transaction.get(usernameRef);
        if (existingUsername.exists) {
          final existingUid = existingUsername.data()?['uid'] as String?;
          if (existingUid != user.uid) {
            throw const UsernameTakenException();
          }
        }

        final profileSnapshot = await transaction.get(userRef);
        final previousLower =
            profileSnapshot.data()?['usernameLower'] as String?;
        final previousUsername = profileSnapshot.data()?['username'] as String?;
        final now = DateTime.now().toIso8601String();

        transaction.set(usernameRef, {
          'uid': user.uid,
          'username': username.trim(),
          'usernameLower': normalized,
          'updatedAt': now,
        });

        if (previousLower != null &&
            previousLower.isNotEmpty &&
            previousLower != normalized) {
          transaction.delete(_usernames.doc(previousLower));
        }

        transaction
          ..set(userRef, {
            'uid': user.uid,
            'email': user.email,
            'displayName': _bestDisplayName(user, previousUsername),
            'photoUrl': user.photoURL,
            'username': username.trim(),
            'usernameLower': normalized,
            'updatedAt': now,
            'createdAt': profileSnapshot.data()?['createdAt'] ?? now,
          }, SetOptions(merge: true))
          ..set(
            publicProfileRef,
            _publicProfileData(
              user: user,
              fallbackUsername: username.trim(),
              username: username.trim(),
              usernameLower: normalized,
              createdAt: profileSnapshot.data()?['createdAt'] as String? ?? now,
              updatedAt: now,
            ),
          );
      });
      return const UsernameClaimResult.success();
    } on UsernameTakenException {
      return const UsernameClaimResult.failure(
        'That username is already taken.',
      );
    } on Exception {
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

    final snapshot = await _publicProfiles
        .where('usernameLower', isGreaterThanOrEqualTo: normalized)
        .where(
          'usernameLower',
          isLessThan: '$normalized\uf8ff',
        )
        .limit(8)
        .get();

    return snapshot.docs
        .map((doc) => UserProfile.fromJson(doc.data()))
        .where((profile) => profile.uid != excludeUid)
        .toList()
      ..sort(
        (left, right) => left.usernameLower!.compareTo(right.usernameLower!),
      );
  }

  Future<List<FriendProfile>> loadFriends({
    required UserProfile me,
    required int todayCount,
  }) async {
    final friendDocs = await _users.doc(me.uid).collection('friends').get();
    final ids = friendDocs.docs
        .map((doc) => doc.id)
        .where((id) => id.isNotEmpty)
        .toList();

    final entries = <FriendProfile>[
      FriendProfile.fromUserProfile(
        me,
        isMe: true,
        todayCount: todayCount,
      ),
    ];

    if (ids.isEmpty) {
      entries.sort(
        (left, right) => right.todayCount.compareTo(left.todayCount),
      );
      return entries;
    }

    final chunks = <List<String>>[];
    for (var index = 0; index < ids.length; index += 10) {
      final end = (index + 10) > ids.length ? ids.length : index + 10;
      chunks.add(ids.sublist(index, end));
    }

    final friendProfiles = <String, UserProfile>{};
    final friendStats = <String, Map<String, dynamic>>{};
    for (final chunk in chunks) {
      final profileSnapshot = await _publicProfiles
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      friendProfiles.addEntries(
        profileSnapshot.docs.map(
          (doc) => MapEntry(doc.id, UserProfile.fromJson(doc.data())),
        ),
      );

      final statsSnapshot = await _friendStats
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      friendStats.addEntries(
        statsSnapshot.docs.map(
          (doc) => MapEntry(doc.id, doc.data()),
        ),
      );
    }

    entries
      ..addAll(
        ids.map((id) {
          final profile = friendProfiles[id];
          if (profile == null) return null;
          final stats = friendStats[id];
          return FriendProfile.fromUserProfile(
            profile.copyWith(
              todayCount: (stats?['todayCount'] as num?)?.toInt(),
              totalAllTime: (stats?['totalAllTime'] as num?)?.toInt(),
              bestDay: (stats?['bestDay'] as num?)?.toInt(),
              streak: (stats?['streak'] as num?)?.toInt(),
            ),
          );
        }).whereType<FriendProfile>(),
      )
      ..sort(
        (left, right) => right.todayCount.compareTo(left.todayCount),
      );
    return entries;
  }

  Future<List<FriendRequest>> loadIncomingFriendRequests({
    required String ownerUid,
  }) async {
    final snapshot = await _users
        .doc(ownerUid)
        .collection('incomingFriendRequests')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => FriendRequest.fromJson(doc.data()))
        .toList();
  }

  Future<List<FriendRequest>> loadOutgoingFriendRequests({
    required String ownerUid,
  }) async {
    final snapshot = await _users
        .doc(ownerUid)
        .collection('outgoingFriendRequests')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => FriendRequest.fromJson(doc.data()))
        .toList();
  }

  Future<void> sendFriendRequest({
    required UserProfile requester,
    required UserProfile receiver,
  }) async {
    if (requester.uid == receiver.uid) return;

    final friendRef = _users
        .doc(requester.uid)
        .collection('friends')
        .doc(receiver.uid);
    final outgoingRef = _users
        .doc(requester.uid)
        .collection('outgoingFriendRequests')
        .doc(receiver.uid);
    final incomingRef = _users
        .doc(receiver.uid)
        .collection('incomingFriendRequests')
        .doc(requester.uid);

    final existingFriend = await friendRef.get();
    final existingRequest = await outgoingRef.get();
    if (existingFriend.exists || existingRequest.exists) return;

    final now = DateTime.now();
    final batch = _firestore.batch()
      ..set(
        incomingRef,
        FriendRequest.fromUserProfile(requester).toJson(createdAt: now),
      )
      ..set(
        outgoingRef,
        FriendRequest.fromUserProfile(receiver).toJson(createdAt: now),
      );
    await batch.commit();
  }

  Future<void> acceptFriendRequest({
    required UserProfile receiver,
    required FriendRequest requester,
  }) async {
    if (receiver.uid == requester.uid) return;

    final now = DateTime.now().toIso8601String();
    final batch = _firestore.batch()
      ..set(
        _users.doc(receiver.uid).collection('friends').doc(requester.uid),
        {
          'uid': requester.uid,
          'addedAt': now,
        },
      )
      ..set(
        _users.doc(requester.uid).collection('friends').doc(receiver.uid),
        {
          'uid': receiver.uid,
          'addedAt': now,
        },
      )
      ..delete(
        _users
            .doc(receiver.uid)
            .collection('incomingFriendRequests')
            .doc(requester.uid),
      )
      ..delete(
        _users
            .doc(requester.uid)
            .collection('outgoingFriendRequests')
            .doc(receiver.uid),
      );
    await batch.commit();
  }

  Future<void> declineFriendRequest({
    required String ownerUid,
    required String requesterUid,
  }) async {
    final batch = _firestore.batch()
      ..delete(
        _users
            .doc(ownerUid)
            .collection('incomingFriendRequests')
            .doc(requesterUid),
      )
      ..delete(
        _users
            .doc(requesterUid)
            .collection('outgoingFriendRequests')
            .doc(ownerUid),
      );
    await batch.commit();
  }

  Future<void> cancelFriendRequest({
    required String ownerUid,
    required String receiverUid,
  }) async {
    final batch = _firestore.batch()
      ..delete(
        _users
            .doc(ownerUid)
            .collection('outgoingFriendRequests')
            .doc(receiverUid),
      )
      ..delete(
        _users
            .doc(receiverUid)
            .collection('incomingFriendRequests')
            .doc(ownerUid),
      );
    await batch.commit();
  }

  Future<void> revokeFriendship({
    required String ownerUid,
    required String friendUid,
  }) async {
    final batch = _firestore.batch()
      ..delete(_users.doc(ownerUid).collection('friends').doc(friendUid))
      ..delete(_users.doc(friendUid).collection('friends').doc(ownerUid));
    await batch.commit();
  }

  Future<void> removeFriend({
    required String ownerUid,
    required String friendUid,
  }) async {
    await revokeFriendship(ownerUid: ownerUid, friendUid: friendUid);
  }

  Future<void> deleteAccountData({required String uid}) async {
    final userRef = _users.doc(uid);
    final userSnapshot = await userRef.get();
    final publicProfileSnapshot = await _publicProfiles.doc(uid).get();
    final usernameLower =
        userSnapshot.data()?['usernameLower'] as String? ??
        publicProfileSnapshot.data()?['usernameLower'] as String?;

    final friendsSnapshot = await userRef.collection('friends').get();
    final incomingSnapshot = await userRef
        .collection('incomingFriendRequests')
        .get();
    final outgoingSnapshot = await userRef
        .collection('outgoingFriendRequests')
        .get();
    final privateStateSnapshot = await userRef.collection('privateState').get();

    final refs = <DocumentReference<Map<String, dynamic>>>[
      ...friendsSnapshot.docs.map((doc) => doc.reference),
      ...friendsSnapshot.docs.map(
        (doc) => _users.doc(doc.id).collection('friends').doc(uid),
      ),
      ...incomingSnapshot.docs.map((doc) => doc.reference),
      ...incomingSnapshot.docs.map(
        (doc) => _users
            .doc(doc.id)
            .collection('outgoingFriendRequests')
            .doc(uid),
      ),
      ...outgoingSnapshot.docs.map((doc) => doc.reference),
      ...outgoingSnapshot.docs.map(
        (doc) => _users
            .doc(doc.id)
            .collection('incomingFriendRequests')
            .doc(uid),
      ),
      ...privateStateSnapshot.docs.map((doc) => doc.reference),
      _publicProfiles.doc(uid),
      _friendStats.doc(uid),
      userRef,
    ];

    if (usernameLower != null && usernameLower.isNotEmpty) {
      refs.add(_usernames.doc(usernameLower));
    }

    await _commitDeletes(refs);
  }

  Future<void> updateStatsFromSnapshot({
    required User user,
    required WorkoutSnapshot snapshot,
  }) async {
    final now = DateTime.now().toIso8601String();
    final userRef = _users.doc(user.uid);
    final publicProfileRef = _publicProfiles.doc(user.uid);
    final userSnapshot = await userRef.get();
    final publicSnapshot = await publicProfileRef.get();
    final privateProfile = userSnapshot.data();
    final publicProfile = publicSnapshot.data();
    final previousUsername =
        privateProfile?['username'] as String? ??
        publicProfile?['username'] as String?;
    final previousUsernameLower =
        privateProfile?['usernameLower'] as String? ??
        publicProfile?['usernameLower'] as String? ??
        (previousUsername == null ? null : normalizeUsername(previousUsername));
    final createdAt =
        privateProfile?['createdAt'] as String? ??
        publicProfile?['createdAt'] as String? ??
        now;
    final todayCount = snapshot.dayTotals[_dayKey(DateTime.now())] ?? 0;
    final bestDay = snapshot.dayTotals.values.isEmpty
        ? 0
        : snapshot.dayTotals.values.reduce(
            (left, right) => left > right ? left : right,
          );
    final totalAllTime = snapshot.dayTotals.values.fold<int>(
      0,
      (total, value) => total + value,
    );

    final privateData = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': _bestDisplayName(user, null),
      'photoUrl': user.photoURL,
      'todayCount': todayCount,
      'bestDay': bestDay,
      'totalAllTime': totalAllTime,
      'streak': _streak(snapshot.dayTotals),
      'updatedAt': now,
    };
    if (previousUsername != null) {
      privateData['username'] = previousUsername;
    }
    if (previousUsernameLower != null) {
      privateData['usernameLower'] = previousUsernameLower;
    }
    final statsData = {
      'uid': user.uid,
      'todayCount': todayCount,
      'bestDay': bestDay,
      'totalAllTime': totalAllTime,
      'streak': _streak(snapshot.dayTotals),
      'updatedAt': now,
    };
    final publicData = _publicProfileData(
      user: user,
      fallbackUsername: previousUsername,
      usernameLower: previousUsernameLower,
      createdAt: createdAt,
      updatedAt: now,
    );

    final batch = _firestore.batch()
      ..set(userRef, privateData, SetOptions(merge: true))
      ..set(_friendStats.doc(user.uid), statsData)
      ..set(publicProfileRef, publicData);
    await batch.commit();
  }

  static Map<String, dynamic> _publicProfileData({
    required User user,
    required String createdAt,
    required String updatedAt,
    String? fallbackUsername,
    String? username,
    String? usernameLower,
  }) {
    final resolvedUsername = username ?? fallbackUsername;
    final data = <String, dynamic>{
      'uid': user.uid,
      'displayName': _bestPublicDisplayName(user, fallbackUsername),
      'photoUrl': user.photoURL,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (resolvedUsername != null) {
      data['username'] = resolvedUsername;
    }
    if (usernameLower != null) {
      data['usernameLower'] = usernameLower;
    }
    return data;
  }

  static String? normalizeUsername(String input) {
    final trimmed = input.trim();
    final lowered = trimmed.toLowerCase();
    final valid = RegExp(r'^[a-z0-9_]{3,20}$');
    if (!valid.hasMatch(lowered)) return null;
    return lowered;
  }

  static String _bestDisplayName(
    User user,
    String? fallback,
  ) {
    final raw = user.displayName?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final email = user.email?.split('@').first.trim();
    if (email != null && email.isNotEmpty) return email;
    final previous = fallback?.trim();
    if (previous != null && previous.isNotEmpty) {
      return previous;
    }
    return 'Pusher';
  }

  static String _bestPublicDisplayName(
    User user,
    String? fallback,
  ) {
    final raw = user.displayName?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final previous = fallback?.trim();
    if (previous != null && previous.isNotEmpty) {
      return previous;
    }
    return 'Pusher';
  }

  static int _streak(Map<String, int> dayTotals) {
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    if ((dayTotals[_dayKey(cursor)] ?? 0) == 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var count = 0;
    while ((dayTotals[_dayKey(cursor)] ?? 0) > 0) {
      count += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static String _dayKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _commitDeletes(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    for (var index = 0; index < refs.length; index += 450) {
      final end = (index + 450) > refs.length ? refs.length : index + 450;
      final batch = _firestore.batch();
      refs.sublist(index, end).forEach(batch.delete);
      await batch.commit();
    }
  }
}
