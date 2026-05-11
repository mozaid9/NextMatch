import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/user_service.dart';

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(this._userService);

  final UserService _userService;

  bool isLoading = false;
  String? errorMessage;

  Stream<AppUser?> userStream(String uid) => _userService.userStream(uid);

  Future<AppUser?> getUser(String uid) => _userService.getUser(uid);

  Future<bool> saveProfile(AppUser user) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _userService.saveProfile(user);
      return true;
    } catch (error) {
      errorMessage = 'Could not save your profile. Please try again.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
