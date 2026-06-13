import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';

/// Thrown by [UserService.claimUsername] when the requested handle is already
/// owned by another player.
class UsernameTakenException implements Exception {
  const UsernameTakenException(this.handle);
  final String handle;
  @override
  String toString() => 'Username @$handle is already taken.';
}

class UserService {
  UserService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Reservation index: one doc per claimed handle, id = canonical handle,
  /// value = { uid }. Guarantees uniqueness via a transaction + rules.
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _firestore.collection('usernames');

  /// Allowed handle shape: 3–20 chars, lowercase letters, digits and
  /// underscores, must start with a letter. Returns null if valid, else a
  /// human-readable reason.
  static String? validateUsername(String raw) {
    final handle = raw.trim().toLowerCase();
    if (handle.isEmpty) return 'Choose a username';
    if (handle.length < 3) return 'At least 3 characters';
    if (handle.length > 20) return 'At most 20 characters';
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(handle)) {
      return 'Letters, numbers and underscores; start with a letter';
    }
    return null;
  }

  /// Canonical form used as both the document id and the stored value.
  static String canonicalUsername(String raw) => raw.trim().toLowerCase();

  /// True if [raw] is free to claim — either unclaimed, or already owned by
  /// [uid] (so re-saving your own handle reads as available).
  Future<bool> isUsernameAvailable(String raw, {required String uid}) async {
    final handle = canonicalUsername(raw);
    if (handle.isEmpty) return false;
    final snapshot = await _usernames.doc(handle).get();
    if (!snapshot.exists) return true;
    return (snapshot.data()?['uid'] as String?) == uid;
  }

  /// Atomically claim [raw] for [uid], releasing the player's previous handle.
  /// Throws [UsernameTakenException] if another player owns it. The race is
  /// closed two ways: the transaction re-reads on contention, and the rules
  /// reject overwriting a handle you don't own.
  Future<void> claimUsername({
    required String uid,
    required String raw,
  }) async {
    final handle = canonicalUsername(raw);
    final newRef = _usernames.doc(handle);
    final userRef = _users.doc(uid);

    await _firestore.runTransaction((txn) async {
      final newSnap = await txn.get(newRef);
      if (newSnap.exists && (newSnap.data()?['uid'] as String?) != uid) {
        throw UsernameTakenException(handle);
      }

      final userSnap = await txn.get(userRef);
      final current = (userSnap.data()?['username'] as String?) ?? '';
      if (current == handle) return; // Already mine — nothing to do.

      txn.set(newRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (current.isNotEmpty) {
        txn.delete(_usernames.doc(current));
      }
      txn.update(userRef, {
        'username': handle,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Toggle the master push preference. The caller is responsible for
  /// (de)registering FCM tokens via NotificationService.
  Future<void> setNotificationsEnabled(String uid, bool enabled) {
    return _users.doc(uid).set(
      {
        'notificationsEnabled': enabled,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  /// Account deletion, "anonymise + release" strategy: free the @handle so it
  /// can be reused, scrub personal fields from the profile doc, and relabel
  /// the player's organised matches so other players' games stay intact with
  /// the organiser shown as "Deleted user". The Firebase Auth user itself is
  /// deleted separately by AuthService. Reputation fields are never touched
  /// (the rules forbid it).
  Future<void> anonymiseAndReleaseAccount(String uid) async {
    final userSnap = await _users.doc(uid).get();
    final handle = (userSnap.data()?['username'] as String?) ?? '';

    final myMatches = await _firestore
        .collection('matches')
        .where('organiserId', isEqualTo: uid)
        .get();

    final batch = _firestore.batch();
    if (handle.isNotEmpty) {
      batch.delete(_usernames.doc(handle));
    }
    for (final doc in myMatches.docs) {
      batch.update(doc.reference, {
        'organiserName': 'Deleted user',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    batch.set(
      _users.doc(uid),
      {
        'fullName': 'Deleted user',
        'username': FieldValue.delete(),
        'email': '',
        'bio': '',
        'location': '',
        'photoUrl': null,
        'deleted': true,
        'deletedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Stream<AppUser?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return AppUser.fromFirestore(snapshot);
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final snapshot = await _users.doc(uid).get();
    if (!snapshot.exists) return null;
    return AppUser.fromFirestore(snapshot);
  }

  Future<void> saveProfile(AppUser user) async {
    final now = DateTime.now();
    final existing = await getUser(user.uid);
    final profile = user.copyWith(
      createdAt: existing?.createdAt ?? user.createdAt,
      updatedAt: now,
    );

    if (existing == null) {
      // First write: create the account doc with its starting reputation.
      await _users.doc(user.uid).set(profile.toMap());
    } else {
      // Edits only ever touch profile-identity fields. Reputation is
      // backend-owned and the security rules reject any client write to it.
      await _users
          .doc(user.uid)
          .set(profile.toProfileMap(), SetOptions(merge: true));
    }
  }

  Future<void> updateProfile(AppUser user) => saveProfile(user);

  /// Uploads a profile photo to Firebase Storage and updates the user's
  /// `photoUrl` field on Firestore. Returns the new public download URL.
  Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref('users/$uid/profile.jpg');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    final url = await ref.getDownloadURL();
    await _users.doc(uid).set(
      {
        'photoUrl': url,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
      SetOptions(merge: true),
    );
    return url;
  }
}
