import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/friends_service.dart';

class FriendsViewModel extends ChangeNotifier {
  FriendsViewModel(this._friendsService);

  final FriendsService _friendsService;

  bool isLoading = false;
  String? errorMessage;

  Stream<List<Friend>> friendsStream(String uid) =>
      _friendsService.friendsStream(uid);

  Future<AppUser?> addFriendByEmail({
    required AppUser me,
    required String email,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _friendsService.addFriendByEmail(me: me, email: email);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<AppUser>> searchUsersByName({
    required AppUser me,
    required String query,
  }) =>
      _friendsService.searchUsersByName(me: me, query: query);

  Future<List<Map<String, dynamic>>> suggestedFriends(String uid) =>
      _friendsService.suggestedFriends(uid: uid);

  Future<AppUser?> getUserById(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!snapshot.exists) return null;
    return AppUser.fromFirestore(snapshot);
  }

  /// Convenience helper used by suggestion / search rows: creates a
  /// friendship directly when we already know the target user's uid,
  /// without going through the email lookup path.
  Future<bool> addFriendByUser({
    required AppUser me,
    required AppUser friend,
  }) async {
    final result = await addFriendByEmail(me: me, email: friend.email);
    return result != null;
  }

  Future<bool> removeFriend({
    required String myUid,
    required String friendUid,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _friendsService.removeFriend(
        myUid: myUid,
        friendUid: friendUid,
      );
      return true;
    } catch (error) {
      errorMessage = 'Could not remove friend.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
