import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/services/auth/firebase_auth_service.dart';

class _Credential extends Fake implements UserCredential {}

class _User extends Fake implements User {
  String? nickname;
  @override
  Future<void> updateDisplayName(String? displayName) async {
    nickname = displayName;
  }

  Object? reloadError;
  Object? tokenError;
  String? token = 'fake-test-token';
  int reloadCalls = 0;
  bool? forceRefresh;
  void Function()? onReload;

  @override
  Future<void> reload() async {
    reloadCalls++;
    if (reloadError != null) throw reloadError!;
    onReload?.call();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    this.forceRefresh = forceRefresh;
    if (tokenError != null) throw tokenError!;
    return token;
  }
}

class _Auth extends Fake implements FirebaseAuth {
  String? verifiedCode;
  String? confirmedCode;
  String? newPassword;

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    verifiedCode = code;
    if (resetError != null) throw resetError!;
    return 'student@example.com';
  }

  @override
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    confirmedCode = code;
    this.newPassword = newPassword;
    if (resetError != null) throw resetError!;
  }

  User? user;
  Stream<User?>? initialState;
  final credential = _Credential();
  String? email;
  String? password;
  Object? loginError;
  Object? signOutError;
  Object? resetError;
  String? resetEmail;
  int signOutCalls = 0;

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => initialState ?? Stream.value(user);

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    this.email = email;
    this.password = password;
    if (loginError != null) throw loginError!;
    return credential;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) throw signOutError!;
    user = null;
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetEmail = email;
    if (resetError != null) throw resetError!;
  }
}

void main() {
  test(
    'reset code verification and confirmation use SDK without signing in',
    () async {
      final auth = _Auth();
      final service = FirebaseAuthService(auth: auth);
      expect(
        await service.verifyPasswordResetCode('fake-test-code'),
        'student@example.com',
      );
      await service.confirmPasswordReset(
        code: 'fake-test-code',
        password: 'new-pass123',
      );
      expect(auth.verifiedCode, 'fake-test-code');
      expect(auth.confirmedCode, 'fake-test-code');
      expect(auth.newPassword, 'new-pass123');
      expect(auth.currentUser, isNull);
    },
  );

  test(
    'reset completion SDK errors propagate without reporting success',
    () async {
      final error = FirebaseAuthException(code: 'expired-action-code');
      final service = FirebaseAuthService(auth: _Auth()..resetError = error);
      await expectLater(
        service.verifyPasswordResetCode('fake-test-code'),
        throwsA(same(error)),
      );
      await expectLater(
        service.confirmPasswordReset(
          code: 'fake-test-code',
          password: 'new-pass123',
        ),
        throwsA(same(error)),
      );
    },
  );

  test('optional nickname updates only the signed-in Auth profile', () async {
    final user = _User();
    await FirebaseAuthService(auth: _Auth()..user = user)
        .updateNickname('  花  ');
    expect(user.nickname, '花');
    await expectLater(
      FirebaseAuthService(auth: _Auth()).updateNickname('花'),
      throwsStateError,
    );
  });

  test('logout calls SDK and next startup has no session to restore', () async {
    final auth = _Auth()..user = _User();
    final service = FirebaseAuthService(auth: auth);
    expect(await service.restoreSession(), isTrue);
    await service.signOut();
    expect(auth.signOutCalls, 1);
    expect(auth.currentUser, isNull);
    expect(await service.restoreSession(), isFalse);
  });

  test(
    'logout failure propagates and does not pretend user signed out',
    () async {
      final user = _User();
      final error = FirebaseAuthException(code: 'network-request-failed');
      final auth = _Auth()
        ..user = user
        ..signOutError = error;
      await expectLater(
        FirebaseAuthService(auth: auth).signOut(),
        throwsA(same(error)),
      );
      expect(auth.currentUser, same(user));
    },
  );

  test(
    'password reset sends trimmed email without changing the session',
    () async {
      final user = _User();
      final auth = _Auth()..user = user;
      await FirebaseAuthService(auth: auth)
          .sendPasswordResetEmail(email: ' student@example.com ');
      expect(auth.resetEmail, 'student@example.com');
      expect(auth.currentUser, same(user));
      expect(auth.signOutCalls, 0);
    },
  );

  test('password reset SDK error propagates to UI', () async {
    final error = FirebaseAuthException(code: 'too-many-requests');
    final auth = _Auth()..resetError = error;
    await expectLater(
      FirebaseAuthService(auth: auth)
          .sendPasswordResetEmail(email: 'student@example.com'),
      throwsA(same(error)),
    );
  });

  test('login forwards trimmed email and unchanged password to SDK', () async {
    final auth = _Auth();
    final service = FirebaseAuthService(auth: auth);
    expect(
      await service.login(
        email: ' student@example.com ',
        password: ' test input ',
      ),
      same(auth.credential),
    );
    expect(auth.email, 'student@example.com');
    expect(auth.password, ' test input ');
  });

  test('login propagates SDK failure to caller', () async {
    final error = FirebaseAuthException(code: 'invalid-credential');
    final auth = _Auth()..loginError = error;
    await expectLater(
      FirebaseAuthService(auth: auth)
          .login(email: 'student@example.com', password: 'test input'),
      throwsA(same(error)),
    );
  });

  test('no saved user does not open home', () async {
    expect(await FirebaseAuthService(auth: _Auth()).restoreSession(), isFalse);
  });

  test('restoration waits for initial Firebase auth event', () async {
    final events = StreamController<User?>();
    addTearDown(events.close);
    final auth = _Auth()..initialState = events.stream;
    var completed = false;
    final result = FirebaseAuthService(auth: auth)
        .restoreSession()
        .then((value) {
          completed = true;
          return value;
        });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    events.add(null);
    expect(await result, isFalse);
  });

  test(
    'saved user is reloaded and token force-refreshed before restoring',
    () async {
      final user = _User();
      final auth = _Auth()..user = user;
      expect(await FirebaseAuthService(auth: auth).restoreSession(), isTrue);
      expect(user.reloadCalls, 1);
      expect(user.forceRefresh, isTrue);
      expect(auth.signOutCalls, 0);
    },
  );

  test('uses the SDK current user after reload', () async {
    final original = _User();
    final refreshed = _User();
    final auth = _Auth()..user = original;
    original.onReload = () => auth.user = refreshed;
    expect(await FirebaseAuthService(auth: auth).restoreSession(), isTrue);
    expect(original.forceRefresh, isNull);
    expect(refreshed.forceRefresh, isTrue);
  });

  test('user disappearing during reload is not restored', () async {
    final user = _User();
    final auth = _Auth()..user = user;
    user.onReload = () => auth.user = null;
    expect(await FirebaseAuthService(auth: auth).restoreSession(), isFalse);
  });

  for (final code in [
    'user-disabled',
    'user-not-found',
    'invalid-user-token',
    'user-token-expired',
  ]) {
    test('$code clears invalid saved session', () async {
      final user = _User()..reloadError = FirebaseAuthException(code: code);
      final auth = _Auth()..user = user;
      expect(await FirebaseAuthService(auth: auth).restoreSession(), isFalse);
      expect(auth.signOutCalls, 1);
      expect(auth.currentUser, isNull);
    });
  }

  test('invalid session during forced refresh also signs out', () async {
    final user = _User()
      ..tokenError = FirebaseAuthException(code: 'user-token-expired');
    final auth = _Auth()..user = user;
    expect(await FirebaseAuthService(auth: auth).restoreSession(), isFalse);
    expect(auth.signOutCalls, 1);
  });

  for (final duringTokenRefresh in [false, true]) {
    test(
      'network failure propagates without clearing saved user (refresh: $duringTokenRefresh)',
      () async {
        final error = FirebaseAuthException(code: 'network-request-failed');
        final user = _User();
        if (duringTokenRefresh) {
          user.tokenError = error;
        } else {
          user.reloadError = error;
        }
        final auth = _Auth()..user = user;
        await expectLater(
          FirebaseAuthService(auth: auth).restoreSession(),
          throwsA(same(error)),
        );
        expect(auth.signOutCalls, 0);
        expect(auth.currentUser, same(user));
      },
    );
  }

  for (final token in <String?>[null, '']) {
    test(
      'missing or empty ID token clears the unusable session ($token)',
      () async {
        final user = _User()..token = token;
        final auth = _Auth()..user = user;
        expect(await FirebaseAuthService(auth: auth).restoreSession(), isFalse);
        expect(auth.signOutCalls, 1);
      },
    );
  }
}
