import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pushlog/auth/models/user_profile.dart';
import 'package:pushlog/friends/models/friend_profile.dart';
import 'package:pushlog/workout/models/data/workout_snapshot.dart';

class UsernameClaimResult {
  const UsernameClaimResult._({
    required this.success,
    this.message,
  });

  const UsernameClaimResult.success()
      : this._(success: true);

  const UsernameClaimResult.failure(String message)
      : this._(success: false, message: message);

  final bool success;
  final String? message;
}

class ProfileService {
  ProfileService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>>
      get _usernames =>
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
    await _users.doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
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
    final usernameRef = _usernames.doc(normalized);

    try {
      await _firestore.runTransaction((transaction) async {
        final existingUsername =
            await transaction.get(usernameRef);
        if (existingUsername.exists) {
          final existingUid =
              existingUsername.data()?['uid'] as String?;
          if (existingUid != user.uid) {
            throw StateError('USERNAME_TAKEN');
          }
        }

        final profileSnapshot =
            await transaction.get(userRef);
        final previousLower =
            profileSnapshot.data()?['usernameLower'] as String?;
        final previousUsername =
            profileSnapshot.data()?['username'] as String?;
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

        transaction.set(userRef, {
          'uid': user.uid,
          'email': user.email,
          'displayName':
              _bestDisplayName(user, previousUsername),
          'photoUrl': user.photoURL,
          'username': username.trim(),
          'usernameLower': normalized,
          'updatedAt': now,
          'createdAt':
              profileSnapshot.data()?['createdAt'] ?? now,
        }, SetOptions(merge: true));
      });
      return const UsernameClaimResult.success();
    } on StateError catch (error) {
      if (error.message == 'USERNAME_TAKEN') {
        return const UsernameClaimResult.failure(
          'That username is already taken.',
        );
      }
      return UsernameClaimResult.failure(error.message);
    } catch (_) {
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

    final snapshot = await _users
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
        (left, right) => left.usernameLower!
            .compareTo(right.usernameLower!),
      );
  }

  Future<List<FriendProfile>> loadFriends({
    required UserProfile me,
    required int todayCount,
  }) async {
    final friendDocs = await _users
        .doc(me.uid)
        .collection('friends')
        .get();
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
        (left, right) =>
            right.todayCount.compareTo(left.todayCount),
      );
      return entries;
    }

    final chunks = <List<String>>[];
    for (var index = 0; index < ids.length; index += 10) {
      final end = (index + 10) > ids.length
          ? ids.length
          : index + 10;
      chunks.add(ids.sublist(index, end));
    }

    final friendProfiles = <UserProfile>[];
    for (final chunk in chunks) {
      final snapshot = await _users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      friendProfiles.addAll(
        snapshot.docs
            .map((doc) => UserProfile.fromJson(doc.data())),
      );
    }

    entries.addAll(
      friendProfiles.map(FriendProfile.fromUserProfile),
    );
    entries.sort(
      (left, right) =>
          right.todayCount.compareTo(left.todayCount),
    );
    return entries;
  }

  Future<void> addFriend({
    required String ownerUid,
    required UserProfile friend,
  }) async {
    if (ownerUid == friend.uid) return;

    await _users
        .doc(ownerUid)
        .collection('friends')
        .doc(friend.uid)
        .set({
      'uid': friend.uid,
      'addedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeFriend({
    required String ownerUid,
    required String friendUid,
  }) async {
    await _users
        .doc(ownerUid)
        .collection('friends')
        .doc(friendUid)
        .delete();
  }

  Future<void> updateStatsFromSnapshot({
    required User user,
    required WorkoutSnapshot snapshot,
  }) async {
    final now = DateTime.now().toIso8601String();
    final todayCount =
        snapshot.dayTotals[_dayKey(DateTime.now())] ?? 0;
    final bestDay = snapshot.dayTotals.values.isEmpty
        ? 0
        : snapshot.dayTotals.values.reduce(
            (left, right) => left > right ? left : right,
          );
    final totalAllTime = snapshot.dayTotals.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    await _users.doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': _bestDisplayName(user, null),
      'photoUrl': user.photoURL,
      'todayCount': todayCount,
      'bestDay': bestDay,
      'totalAllTime': totalAllTime,
      'streak': _streak(snapshot.dayTotals),
      'updatedAt': now,
    }, SetOptions(merge: true));
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
}
