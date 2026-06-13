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

  /// The sign-in method backing the current account: 'password', 'google.com'
  /// or 'apple.com'. Drives which re-auth flow the delete confirmation uses.
  String get primaryProviderId {
    final providers = _firebaseAuth.currentUser?.providerData ?? const [];
    if (providers.isEmpty) return 'password';
    return providers.first.providerId;
  }

  /// Re-authenticate a password user. Firebase requires a fresh credential
  /// before sensitive actions like account deletion.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user to re-authenticate.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Re-authenticate an OAuth user (Google/Apple) via popup.
  Future<void> reauthenticateWithProvider(String providerId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user to re-authenticate.',
      );
    }
    final AuthProvider provider = switch (providerId) {
      'google.com' => GoogleAuthProvider()..addScope('email'),
      'apple.com' => OAuthProvider('apple.com')..addScope('email'),
      _ => throw FirebaseAuthException(
        code: 'unsupported-provider',
        message: 'Re-authentication for $providerId is not supported here.',
      ),
    };
    await user.reauthenticateWithPopup(provider);
  }

  /// Permanently delete the Firebase Auth user. Call only after Firestore
  /// cleanup, since this drops the credential the writes depend on.
  Future<void> deleteAccount() => _firebaseAuth.currentUser!.delete();

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

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
      'requires-recent-login' =>
        'For security, please confirm your password to continue.',
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
