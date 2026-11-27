import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/registration_screen.dart';
import 'package:yorisoi/services/auth/firebase_auth_service.dart';

class _ProfileUser extends Fake implements User {
  @override
  String get uid => 'integration-fixture-user';
  int writes = 0;
  String? name;
  @override
  Future<void> updateDisplayName(String? displayName) async {
    writes++;
    if (writes == 1) {
      throw FirebaseAuthException(code: 'network-request-failed');
    }
    name = displayName;
  }
}

class _ProfileCredential extends Fake implements UserCredential {
  _ProfileCredential(this.user);
  @override
  final User user;
}

class _ProfileAuth extends Fake implements FirebaseAuth {
  final user = _ProfileUser();
  int creates = 0;
  @override
  User? get currentUser => user;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    creates++;
    return _ProfileCredential(user);
  }
}

Future<void> fill(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('auth-nickname')), '  さくら  ');
  await tester.enterText(
    find.byKey(const Key('auth-email')),
    'student@example.invalid',
  );
  await tester.enterText(find.byKey(const Key('auth-password')), '123456');
  await tester.enterText(find.byKey(const Key('auth-confirmation')), '123456');
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('auth-submit')));
  await tester.tap(find.byKey(const Key('auth-submit')));
  await tester.pump();
}

void main() {
  testWidgets(
    'widget to real AuthService integration retries only the failed fake SDK profile write',
    (tester) async {
      final auth = _ProfileAuth();
      final service = FirebaseAuthService(auth: auth);
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationScreen(
            registrationAction:
                ({required email, required password, nickname}) async {
                  await service.register(
                    email: email,
                    password: password,
                    nickname: nickname,
                  );
                },
            nicknameUpdateAction: (id, name) => service
                .retryRegistrationNickname(expectedUserId: id, nickname: name),
          ),
        ),
      );
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('registration-profile-warning')),
        findsOneWidget,
      );
      expect(auth.creates, 1);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(auth.creates, 1);
      expect(auth.user.writes, 2);
      expect(auth.user.name, 'さくら');
      expect(find.text('登録が完了しました。'), findsOneWidget);
    },
  );
  testWidgets(
    'nickname and six-character password are forwarded without changing validation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationScreen(
            registrationAction:
                ({required email, required password, nickname}) async {
                  expect(nickname, 'さくら');
                  expect(password, '123456');
                },
          ),
        ),
      );
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('登録が完了しました。'), findsOneWidget);
      expect(find.text('6文字以上 · 6+ characters'), findsOneWidget);
    },
  );

  testWidgets(
    'profile-only retry blocks duplicate writes and never recreates the account',
    (tester) async {
      var creates = 0;
      var profileWrites = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationScreen(
            registrationAction:
                ({required email, required password, nickname}) async {
                  creates++;
                  throw const RegistrationProfileException(
                    userId: 'fixture-user',
                  );
                },
            nicknameUpdateAction: (id, name) {
              profileWrites++;
              expect(id, 'fixture-user');
              expect(name, 'さくら');
              return pending.future;
            },
          ),
        ),
      );
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('registration-profile-warning')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('auth-email')))
            .enabled,
        isFalse,
      );
      final button = tester
          .widget<ElevatedButton>(find.byKey(const Key('auth-submit')))
          .onPressed!;
      button();
      button();
      await tester.pump();
      expect(creates, 1);
      expect(profileWrites, 1);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('registration-without-nickname')),
            )
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('登録が完了しました。'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('auth-submit')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'failed retry shows safe feedback and explicit continue does not recreate',
    (tester) async {
      var creates = 0;
      var writes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationScreen(
            registrationAction:
                ({required email, required password, nickname}) async {
                  creates++;
                  throw const RegistrationProfileException(
                    userId: 'fixture-user',
                  );
                },
            nicknameUpdateAction: (_, _) async {
              writes++;
              throw StateError('private server details');
            },
          ),
        ),
      );
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('private server'), findsNothing);
      expect(find.textContaining('名前を保存できませんでした'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('registration-without-nickname')),
      );
      await tester.tap(find.byKey(const Key('registration-without-nickname')));
      await tester.pumpAndSettle();
      expect(find.text('アカウントを作成しました。ニックネームの保存は未確認です。'), findsOneWidget);
      expect(creates, 1);
      expect(writes, 1);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('auth-submit')))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('late profile retry completion after disposal is ignored', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationScreen(
          registrationAction:
              ({required email, required password, nickname}) async =>
                  throw const RegistrationProfileException(
                    userId: 'fixture-user',
                  ),
          nicknameUpdateAction: (_, _) => pending.future,
        ),
      ),
    );
    await fill(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    await submit(tester);
    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('private retry'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
