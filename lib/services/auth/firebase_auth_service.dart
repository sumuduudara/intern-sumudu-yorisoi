import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Firebase clears the persisted session as well as the current user.
  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Web remembers this session across reloads on the same browser origin.
  /// Android/iOS persistence is managed by the Firebase SDK itself.
  Future<void> _configurePersistence() async {
    if (kIsWeb) await _auth.setPersistence(Persistence.LOCAL);
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    await _configurePersistence();
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Wait for Firebase's initial restored state, then check it with the server.
  /// Network errors propagate so startup can offer retry without signing out.
  Future<bool> restoreSession() async {
    await _configurePersistence();
    final user = await _auth.authStateChanges().first;
    if (user == null) return false;

    try {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) return false;
      final token = await refreshedUser.getIdToken(true);
      if (token == null || token.isEmpty) {
        await _auth.signOut();
        return false;
      }
      return true;
    } on FirebaseAuthException catch (error) {
      const invalidSessionCodes = {
        'user-disabled',
        'user-not-found',
        'invalid-user-token',
        'user-token-expired',
      };
      if (!invalidSessionCodes.contains(error.code)) rethrow;
      await _auth.signOut();
      return false;
    }
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }
}
