import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/app_user.dart';

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
