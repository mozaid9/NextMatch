import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    // Explicitly persist auth state in local storage (web default, but be explicit).
    if (kIsWeb) {
      _firebaseAuth.setPersistence(Persistence.LOCAL);
    }
  }

  final FirebaseAuth _firebaseAuth;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    return credential;
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  /// Google Sign-In via popup (web). Requires Google provider enabled in
  /// Firebase Console → Authentication → Sign-in methods.
  Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');
    return _firebaseAuth.signInWithPopup(provider);
  }

  /// Apple Sign-In via popup (web). Requires Apple provider enabled in
  /// Firebase Console → Authentication → Sign-in methods, plus a registered
  /// Apple Service ID and private key.
  Future<UserCredential> signInWithApple() async {
    final provider = OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    return _firebaseAuth.signInWithPopup(provider);
  }

  String friendlyAuthError(Object error) {
    if (_isPlaceholderFirebaseConfig()) {
      return 'Firebase is still using placeholder API keys. Add .env.firebase locally and run with --dart-define-from-file=.env.firebase.';
    }

    if (error is FirebaseException) {
      final message = error.message ?? '';
      if (error.code == 'invalid-api-key' ||
          message.contains('API key not valid')) {
        return 'Firebase rejected the API key. Check your local .env.firebase values, then restart the app.';
      }
    }

    if (error is! FirebaseAuthException) return 'Something went wrong.';

    return switch (error.code) {
      'email-already-in-use' => 'An account already exists for that email.',
      'invalid-email' => 'Enter a valid email address.',
      'invalid-api-key' =>
        'Firebase rejected the API key. Check your local .env.firebase values, then restart the app.',
      'operation-not-allowed' =>
        'This sign-in method is not enabled. Enable it in Firebase Console → Authentication.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found for that email.',
      'wrong-password' => 'Incorrect password.',
      'invalid-credential' => 'Email or password is incorrect.',
      'weak-password' => 'Use a stronger password.',
      'popup-closed-by-user' || 'cancelled-popup-request' => '',
      'account-exists-with-different-credential' =>
        'An account already exists with this email. Try signing in with email/password.',
      'popup-blocked' =>
        'Popup was blocked by the browser. Allow popups for this site and try again.',
      _ => error.message ?? 'Authentication failed.',
    };
  }

  bool _isPlaceholderFirebaseConfig() {
    if (Firebase.apps.isEmpty) return false;

    final options = Firebase.app().options;
    return options.apiKey.startsWith('REPLACE_WITH') ||
        options.appId.startsWith('REPLACE_WITH') ||
        options.messagingSenderId.startsWith('REPLACE_WITH');
  }
}
