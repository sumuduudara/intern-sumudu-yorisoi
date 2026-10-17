import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

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
