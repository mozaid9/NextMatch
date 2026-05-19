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

  Stream<List<Friend>> followingStream(String uid) =>
      _friendsService.followingStream(uid);

  Stream<List<Friend>> followersStream(String uid) =>
      _friendsService.followersStream(uid);

  Stream<FollowStatus> followStatusStream({
    required String viewerUid,
    required String targetUid,
  }) =>
      _friendsService.followStatusStream(
        viewerUid: viewerUid,
        targetUid: targetUid,
      );

  Future<bool> follow({
    required AppUser me,
    required AppUser target,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _friendsService.follow(me: me, target: target);
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> unfollow({
    required String myUid,
    required String targetUid,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _friendsService.unfollow(myUid: myUid, targetUid: targetUid);
      return true;
    } catch (error) {
      errorMessage = 'Could not unfollow.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<AppUser?> followByEmail({
    required AppUser me,
    required String email,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _friendsService.followByEmail(me: me, email: email);
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
}
