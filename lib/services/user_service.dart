import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

    await _users.doc(user.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> updateProfile(AppUser user) => saveProfile(user);
}
