import 'package:firebase_auth/firebase_auth.dart';

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
    if (error is! FirebaseAuthException) return 'Something went wrong.';

    return switch (error.code) {
      'email-already-in-use' => 'An account already exists for that email.',
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found for that email.',
      'wrong-password' => 'Incorrect password.',
      'invalid-credential' => 'Email or password is incorrect.',
      'weak-password' => 'Use a stronger password.',
      _ => error.message ?? 'Authentication failed.',
    };
  }
}
