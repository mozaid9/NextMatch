import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

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

  String friendlyAuthError(Object error) {
    if (_isPlaceholderFirebaseConfig()) {
      return 'Firebase is still using placeholder API keys. Run flutterfire configure locally, then restart the app.';
    }

    if (error is FirebaseException) {
      final message = error.message ?? '';
      if (error.code == 'invalid-api-key' ||
          message.contains('API key not valid')) {
        return 'Firebase rejected the API key. Refresh your local Firebase config with flutterfire configure.';
      }
    }

    if (error is! FirebaseAuthException) return 'Something went wrong.';

    return switch (error.code) {
      'email-already-in-use' => 'An account already exists for that email.',
      'invalid-email' => 'Enter a valid email address.',
      'invalid-api-key' =>
        'Firebase rejected the API key. Refresh your local Firebase config with flutterfire configure.',
      'operation-not-allowed' =>
        'Email/password login is not enabled for this Firebase project.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found for that email.',
      'wrong-password' => 'Incorrect password.',
      'invalid-credential' => 'Email or password is incorrect.',
      'weak-password' => 'Use a stronger password.',
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
