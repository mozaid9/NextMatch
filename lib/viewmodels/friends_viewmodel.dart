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
