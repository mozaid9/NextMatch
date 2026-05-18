import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Lightweight friendship snapshot stored on each user's friends subcollection.
/// Denormalised for fast list rendering — we don't need a live profile fetch
/// every time you open the friends list.
class Friend {
  const Friend({
    required this.uid,
    required this.fullName,
    required this.photoUrl,
    required this.position,
    required this.skillLevel,
    required this.reliabilityScore,
    required this.addedAt,
  });

  final String uid;
  final String fullName;
  final String? photoUrl;
  final String position;
  final String skillLevel;
  final int reliabilityScore;
  final DateTime addedAt;

  factory Friend.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return Friend(
      uid: data['uid'] as String? ?? document.id,
      fullName: data['fullName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      position: data['position'] as String? ?? 'Any',
      skillLevel: data['skillLevel'] as String? ?? 'Casual',
      reliabilityScore: (data['reliabilityScore'] as num?)?.toInt() ?? 100,
      addedAt: _readDate(data['addedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fullName': fullName,
        'photoUrl': photoUrl,
        'position': position,
        'skillLevel': skillLevel,
        'reliabilityScore': reliabilityScore,
        'addedAt': Timestamp.fromDate(addedAt),
      };

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}

class FriendsService {
  FriendsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<List<Friend>> friendsStream(String uid) {
    return _users
        .doc(uid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Friend.fromFirestore).toList(growable: false),
        );
  }

  /// Adds a friendship symmetrically — writes both `users/<a>/friends/<b>`
  /// and `users/<b>/friends/<a>`. Looks up the target user by email.
  ///
  /// Returns the resolved AppUser on success. Throws on validation errors.
  Future<AppUser> addFriendByEmail({
    required AppUser me,
    required String email,
  }) async {
    final trimmed = email.trim().toLowerCase();
    if (trimmed.isEmpty) {
      throw Exception('Enter an email address.');
    }
    if (trimmed == me.email.toLowerCase()) {
      throw Exception("That's your own email.");
    }

    // Look up by email. Note this needs a single-field index on `email`
    // which Firestore auto-creates on first query.
    final result = await _users
        .where('email', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (result.docs.isEmpty) {
      throw Exception('No NextMatch account uses that email.');
    }
    final friend = AppUser.fromFirestore(result.docs.first);
    if (friend.uid == me.uid) {
      throw Exception("That's your own account.");
    }

    final myFriendRef =
        _users.doc(me.uid).collection('friends').doc(friend.uid);
    final theirFriendRef =
        _users.doc(friend.uid).collection('friends').doc(me.uid);

    final existing = await myFriendRef.get();
    if (existing.exists) {
      throw Exception('${friend.fullName} is already in your friends list.');
    }

    final now = DateTime.now();
    final batch = _firestore.batch();
    batch.set(
      myFriendRef,
      Friend(
        uid: friend.uid,
        fullName: friend.fullName,
        photoUrl: friend.photoUrl,
        position: friend.preferredPosition,
        skillLevel: friend.skillLevel,
        reliabilityScore: friend.reliabilityScore,
        addedAt: now,
      ).toMap(),
    );
    batch.set(
      theirFriendRef,
      Friend(
        uid: me.uid,
        fullName: me.fullName,
        photoUrl: me.photoUrl,
        position: me.preferredPosition,
        skillLevel: me.skillLevel,
        reliabilityScore: me.reliabilityScore,
        addedAt: now,
      ).toMap(),
    );
    await batch.commit();
    return friend;
  }

  Future<void> removeFriend({
    required String myUid,
    required String friendUid,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_users.doc(myUid).collection('friends').doc(friendUid));
    batch.delete(_users.doc(friendUid).collection('friends').doc(myUid));
    await batch.commit();
  }
}
