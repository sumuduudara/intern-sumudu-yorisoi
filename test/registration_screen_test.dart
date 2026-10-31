import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/registration_screen.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';

void main() {
  Future<void> open(WidgetTester tester, RegistrationAction action) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: RegistrationScreen(registrationAction: action)),
    );
  }

  Future<void> fill(
    WidgetTester tester, {
    String email = 'test@example.com',
    String password = 'secret123',
    String confirmation = 'secret123',
  }) async {
    await tester.enterText(find.byKey(const Key('registration-email')), email);
    await tester.enterText(
      find.byKey(const Key('registration-password')),
      password,
    );
    await tester.enterText(
      find.byKey(const Key('registration-confirmation')),
      confirmation,
    );
  }

  testWidgets('invalid input never submits', (tester) async {
    var calls = 0;
    await open(tester, ({required email, required password}) async {
      calls++;
    });
    await tester.tap(find.byKey(const Key('auth-register-submit')));
    await tester.pump();
    expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsOneWidget);
    expect(find.text('パスワード確認を入力してください'), findsOneWidget);
    await fill(
      tester,
      email: 'invalid',
      password: '12345',
      confirmation: 'other',
    );
    await tester.tap(find.byKey(const Key('auth-register-submit')));
    await tester.pump();
    expect(find.text('正しいメールアドレスを入力してください'), findsOneWidget);
    expect(find.text('パスワードは6文字以上で入力してください'), findsOneWidget);
    expect(find.text('パスワードが一致しません'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('pending submission blocks duplicates and shows success', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await open(tester, ({required email, required password}) {
      calls++;
      expect(email, 'test@example.com');
      expect(password, 'secret123');
      return pending.future;
    });
    await fill(tester, email: ' test@example.com ');
    await tester.tap(find.byKey(const Key('auth-register-submit')));
    await tester.pump();
    expect(find.text('登録中...'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('登録中...'));
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('登録が完了しました。'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
      isFalse,
    );
  });

  final errors = {
    'email-already-in-use': 'このメールアドレスはすでに登録されています。',
    'invalid-email': '正しいメールアドレスを入力してください。',
    'weak-password': 'より安全なパスワードを入力してください（6文字以上）。',
    'network-request-failed': '通信に失敗しました。接続を確認して、もう一度お試しください。',
    'too-many-requests': '試行回数が多すぎます。しばらく待ってからお試しください。',
    'operation-not-allowed': '現在、新規登録をご利用いただけません。時間をおいてお試しください。',
    'unknown': '登録に失敗しました。しばらく待ってからもう一度お試しください。',
  };
  for (final error in errors.entries) {
    testWidgets('${error.key} shows Japanese error and allows retry', (
      tester,
    ) async {
      await open(tester, ({required email, required password}) async {
        throw FirebaseAuthException(code: error.key);
      });
      await fill(tester);
      await tester.tap(find.byKey(const Key('auth-register-submit')));
      await tester.pumpAndSettle();
      expect(find.text(error.value), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
    });
  }

  testWidgets(
    'completion after leaving screen does not access disposed state',
    (tester) async {
      final pending = Completer<void>();
      await open(
        tester,
        ({required email, required password}) => pending.future,
      );
      await fill(tester);
      await tester.tap(find.byKey(const Key('auth-register-submit')));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
