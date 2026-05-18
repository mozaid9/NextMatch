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

  /// Returns users whose name contains (case-insensitive) the query.
  /// MVP implementation: pulls up to 50 users and filters client-side.
  /// Self and existing friends are excluded.
  Future<List<AppUser>> searchUsersByName({
    required AppUser me,
    required String query,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final friendsSnap =
        await _users.doc(me.uid).collection('friends').get();
    final friendUids = friendsSnap.docs.map((d) => d.id).toSet();

    final all = await _users.limit(50).get();
    final results = all.docs
        .map(AppUser.fromFirestore)
        .where((user) =>
            user.uid != me.uid &&
            !friendUids.contains(user.uid) &&
            user.fullName.toLowerCase().contains(q))
        .toList(growable: false);
    return results;
  }

  /// "People you may know" — users I've shared at least one completed
  /// match with who aren't already in my friends list. Ranked by how
  /// many matches we've appeared in together.
  Future<List<Map<String, dynamic>>> suggestedFriends({
    required String uid,
  }) async {
    final friendsSnap =
        await _users.doc(uid).collection('friends').get();
    final friendUids = friendsSnap.docs.map((d) => d.id).toSet();

    final joinedDocs = await _users
        .doc(uid)
        .collection('joinedMatches')
        .limit(30)
        .get();
    final matchIds = joinedDocs.docs
        .map((d) => d.data()['matchId'] as String?)
        .whereType<String>()
        .toList();
    if (matchIds.isEmpty) return [];

    final matches = _firestore.collection('matches');
    final Map<String, Map<String, dynamic>> suggestions = {};
    for (final matchId in matchIds) {
      final snap = await matches.doc(matchId).collection('participants').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final playerId = data['userId'] as String? ?? doc.id;
        if (playerId == uid) continue;
        if (friendUids.contains(playerId)) continue;
        final name = data['fullName'] as String? ?? '';
        if (name.isEmpty) continue;
        final photoUrl = data['photoUrl'] as String?;
        if (suggestions.containsKey(playerId)) {
          suggestions[playerId]!['count'] =
              (suggestions[playerId]!['count'] as int) + 1;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            suggestions[playerId]!['photoUrl'] = photoUrl;
          }
        } else {
          suggestions[playerId] = {
            'userId': playerId,
            'fullName': name,
            'photoUrl': photoUrl,
            'count': 1,
          };
        }
      }
    }

    final sorted = suggestions.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return sorted.take(8).toList();
  }
}
