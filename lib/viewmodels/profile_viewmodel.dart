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

  /// True if [raw] is free for [uid] to claim.
  Future<bool> isUsernameAvailable(String raw, {required String uid}) =>
      _userService.isUsernameAvailable(raw, uid: uid);

  /// Atomically claim a handle. Returns true on success; on failure sets
  /// [errorMessage] (taken, or a transient error) and returns false.
  Future<bool> claimUsername({
    required String uid,
    required String raw,
  }) async {
    final reason = UserService.validateUsername(raw);
    if (reason != null) {
      errorMessage = reason;
      notifyListeners();
      return false;
    }
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _userService.claimUsername(uid: uid, raw: raw);
      return true;
    } on UsernameTakenException catch (e) {
      errorMessage = 'That username is taken — try @${e.handle}_ or another.';
      return false;
    } catch (_) {
      errorMessage = 'Could not save your username. Please try again.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setNotificationsEnabled(String uid, bool enabled) async {
    try {
      await _userService.setNotificationsEnabled(uid, enabled);
      return true;
    } catch (error) {
      errorMessage = 'Could not update notifications. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Anonymise the profile and release the @handle. Returns true on success.
  Future<bool> anonymiseAndReleaseAccount(String uid) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _userService.anonymiseAndReleaseAccount(uid);
      return true;
    } catch (_) {
      errorMessage = 'Could not delete your data. Please try again.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _userService.uploadProfilePhoto(
        uid: uid,
        bytes: bytes,
        contentType: contentType,
      );
    } catch (error) {
      errorMessage = 'Upload failed: $error';
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
