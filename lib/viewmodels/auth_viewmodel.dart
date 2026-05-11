import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authService);

  final AuthService _authService;

  bool isLoading = false;
  String? errorMessage;

  Stream<User?> get authStateChanges => _authService.authStateChanges;
  User? get currentUser => _authService.currentUser;

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _runAuthAction(
      () => _authService.register(name: name, email: email, password: password),
    );
  }

  Future<bool> login({required String email, required String password}) async {
    return _runAuthAction(
      () => _authService.login(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<bool> _runAuthAction(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } catch (error) {
      errorMessage = _authService.friendlyAuthError(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
