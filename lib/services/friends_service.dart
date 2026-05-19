import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Where a viewer stands in relation to another user.
/// - [notFollowing]: viewer does not follow target
/// - [following]: viewer follows target, target does not follow back
/// - [mutual]: both follow each other — counts as a "friend"
enum FollowStatus { notFollowing, following, mutual }

/// Lightweight player snapshot used for both `following/` and `followers/`
/// subcollections, and for "Your friends" (mutual follows). Denormalised
/// so we don't need a live profile fetch every time you open a list.
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

/// Social graph service.
///
/// The model is Instagram-style: a viewer can [follow] a target without
/// the target's consent. When two users follow each other they are
/// considered "friends" (mutual).
///
/// Firestore layout:
///   users/{uid}/following/{targetUid}  — denormalised target snapshot
///   users/{uid}/followers/{followerUid} — denormalised follower snapshot
class FriendsService {
  FriendsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> _following(String uid) =>
      _users.doc(uid).collection('following');

  CollectionReference<Map<String, dynamic>> _followers(String uid) =>
      _users.doc(uid).collection('followers');

  /// People you follow.
  Stream<List<Friend>> followingStream(String uid) {
    return _following(uid)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Friend.fromFirestore).toList(growable: false),
        );
  }

  /// People who follow you.
  Stream<List<Friend>> followersStream(String uid) {
    return _followers(uid)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Friend.fromFirestore).toList(growable: false),
        );
  }

  /// "Friends" = users where you follow them and they follow you back.
  /// Computed as the intersection of your `following` and `followers`.
  Stream<List<Friend>> friendsStream(String uid) {
    final controller = StreamController<List<Friend>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? followingSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? followersSub;
    QuerySnapshot<Map<String, dynamic>>? followingSnap;
    QuerySnapshot<Map<String, dynamic>>? followersSnap;

    void emit() {
      if (followingSnap == null || followersSnap == null) return;
      final followerIds = followersSnap!.docs.map((d) => d.id).toSet();
      final friends = followingSnap!.docs
          .where((d) => followerIds.contains(d.id))
          .map(Friend.fromFirestore)
          .toList(growable: false);
      controller.add(friends);
    }

    controller.onListen = () {
      followingSub = _following(uid).snapshots().listen((snap) {
        followingSnap = snap;
        emit();
      }, onError: controller.addError);
      followersSub = _followers(uid).snapshots().listen((snap) {
        followersSnap = snap;
        emit();
      }, onError: controller.addError);
    };
    controller.onCancel = () async {
      await followingSub?.cancel();
      await followersSub?.cancel();
    };

    return controller.stream;
  }

  /// Live follow-status of [viewerUid] toward [targetUid].
  Stream<FollowStatus> followStatusStream({
    required String viewerUid,
    required String targetUid,
  }) {
    if (viewerUid == targetUid) {
      return Stream.value(FollowStatus.notFollowing);
    }
    final controller = StreamController<FollowStatus>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? followingSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? followerSub;
    bool? iFollowThem;
    bool? theyFollowMe;

    void emit() {
      if (iFollowThem == null || theyFollowMe == null) return;
      if (iFollowThem! && theyFollowMe!) {
        controller.add(FollowStatus.mutual);
      } else if (iFollowThem!) {
        controller.add(FollowStatus.following);
      } else {
        controller.add(FollowStatus.notFollowing);
      }
    }

    controller.onListen = () {
      followingSub = _following(viewerUid).doc(targetUid).snapshots().listen(
        (doc) {
          iFollowThem = doc.exists;
          emit();
        },
        onError: controller.addError,
      );
      followerSub = _followers(viewerUid).doc(targetUid).snapshots().listen(
        (doc) {
          theyFollowMe = doc.exists;
          emit();
        },
        onError: controller.addError,
      );
    };
    controller.onCancel = () async {
      await followingSub?.cancel();
      await followerSub?.cancel();
    };

    return controller.stream;
  }

  /// Start following [target]. Writes my-side `following` doc AND the
  /// target's `followers` doc so both lists stay in sync.
  Future<void> follow({
    required AppUser me,
    required AppUser target,
  }) async {
    if (me.uid == target.uid) {
      throw Exception("You can't follow yourself.");
    }

    final myFollowingRef = _following(me.uid).doc(target.uid);
    final theirFollowerRef = _followers(target.uid).doc(me.uid);

    final existing = await myFollowingRef.get();
    if (existing.exists) return; // already following — no-op

    final now = DateTime.now();
    final batch = _firestore.batch();
    batch.set(
      myFollowingRef,
      Friend(
        uid: target.uid,
        fullName: target.fullName,
        photoUrl: target.photoUrl,
        position: target.preferredPosition,
        skillLevel: target.skillLevel,
        reliabilityScore: target.reliabilityScore,
        addedAt: now,
      ).toMap(),
    );
    batch.set(
      theirFollowerRef,
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
  }

  /// Stop following [targetUid]. Only removes one direction — if the
  /// target was following you back, they keep following you (you just
  /// drop out of their followed list).
  Future<void> unfollow({
    required String myUid,
    required String targetUid,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_following(myUid).doc(targetUid));
    batch.delete(_followers(targetUid).doc(myUid));
    await batch.commit();
  }

  /// Follow someone by email — used by the "find by email" flow when
  /// you can't find them by name. Looks up the user, then calls [follow].
  Future<AppUser> followByEmail({
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

    final result = await _users
        .where('email', isEqualTo: trimmed)
        .limit(1)
        .get();
    if (result.docs.isEmpty) {
      throw Exception('No NextMatch account uses that email.');
    }
    final target = AppUser.fromFirestore(result.docs.first);
    if (target.uid == me.uid) {
      throw Exception("That's your own account.");
    }
    final existing = await _following(me.uid).doc(target.uid).get();
    if (existing.exists) {
      throw Exception('You already follow ${target.fullName}.');
    }
    await follow(me: me, target: target);
    return target;
  }

  /// Returns users whose name contains (case-insensitive) the query.
  /// MVP implementation: pulls up to 50 users and filters client-side.
  /// Self and users you already follow are excluded.
  Future<List<AppUser>> searchUsersByName({
    required AppUser me,
    required String query,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final followingSnap = await _following(me.uid).get();
    final excluded = followingSnap.docs.map((d) => d.id).toSet();

    final all = await _users.limit(50).get();
    final results = all.docs
        .map(AppUser.fromFirestore)
        .where((user) =>
            user.uid != me.uid &&
            !excluded.contains(user.uid) &&
            user.fullName.toLowerCase().contains(q))
        .toList(growable: false);
    return results;
  }

  /// "People you may know" — users I've shared at least one completed
  /// match with who I don't already follow. Ranked by how many matches
  /// we've appeared in together.
  Future<List<Map<String, dynamic>>> suggestedFriends({
    required String uid,
  }) async {
    final followingSnap = await _following(uid).get();
    final excluded = followingSnap.docs.map((d) => d.id).toSet();

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
        if (excluded.contains(playerId)) continue;
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
