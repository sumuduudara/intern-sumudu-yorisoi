import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/presentation/screens/login_screen.dart';
import 'package:yorisoi/presentation/screens/registration_screen.dart';
import 'package:yorisoi/presentation/screens/welcome_screen.dart';

void main() {
  Future<void> open(WidgetTester tester, LoginAction action) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(loginAction: action)),
    );
  }

  Future<void> fill(
    WidgetTester tester, {
    String email = 'student@example.com',
    String password = 'test-only-value',
  }) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
  }

  testWidgets('required fields and invalid email never submit', (tester) async {
    var calls = 0;
    await open(tester, ({required email, required password}) async {
      calls++;
    });
    await tester.tap(find.byKey(const Key('auth-login-submit')));
    await tester.pump();
    expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsOneWidget);
    await fill(tester, email: 'invalid');
    await tester.tap(find.byKey(const Key('auth-login-submit')));
    await tester.pump();
    expect(find.text('正しいメールアドレスを入力してください'), findsOneWidget);
    expect(calls, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isTrue,
    );
  });

  testWidgets(
    'pending login blocks duplicate calls and forwards unchanged password',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await open(tester, ({required email, required password}) {
        expect(email, 'student@example.com');
        expect(password, ' x '); // Login has no registration-only length rule.
        calls++;
        return pending.future;
      });
      await fill(tester, email: ' student@example.com ', password: ' x ');
      await tester.tap(find.byKey(const Key('auth-login-submit')));
      await tester.pump();
      expect(find.text('ログイン中...'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.descendant(
                of: find.byKey(const Key('auth-switch-registration')),
                matching: find.byType(TextButton),
              ),
            )
            .onPressed,
        isNull,
      );
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.enabled, isFalse);
      }
      await tester.tap(find.text('ログイン中...'));
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    },
  );

  testWidgets('successful login removes welcome and login route history', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    final context = tester.element(find.byType(WelcomeScreen));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          loginAction: ({required email, required password}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.ensureVisible(find.byKey(const Key('auth-login-submit')));
    await tester.tap(find.byKey(const Key('auth-login-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
      isFalse,
    );
  });

  final errors = {
    'invalid-credential': 'メールアドレスまたはパスワードが正しくありません。',
    'invalid-login-credentials': 'メールアドレスまたはパスワードが正しくありません。',
    'wrong-password': 'メールアドレスまたはパスワードが正しくありません。',
    'user-not-found': 'メールアドレスまたはパスワードが正しくありません。',
    'invalid-email': '正しいメールアドレスを入力してください。',
    'user-disabled': 'このアカウントは無効になっています。',
    'network-request-failed': '通信に失敗しました。接続を確認して、もう一度お試しください。',
    'too-many-requests': '試行回数が多すぎます。しばらく待ってからお試しください。',
    'operation-not-allowed': '現在、ログインをご利用いただけません。時間をおいてお試しください。',
    'unknown': 'ログインに失敗しました。しばらく待ってからもう一度お試しください。',
  };
  for (final entry in errors.entries) {
    testWidgets('${entry.key} displays Japanese error and allows retry', (
      tester,
    ) async {
      var calls = 0;
      await open(tester, ({required email, required password}) async {
        calls++;
        if (calls == 1) throw FirebaseAuthException(code: entry.key);
      });
      await fill(tester);
      await tester.tap(find.byKey(const Key('auth-login-submit')));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('auth-login-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(calls, 2);
    });
  }

  testWidgets('unexpected exception uses generic Japanese message', (
    tester,
  ) async {
    await open(tester, ({required email, required password}) async {
      throw StateError('test error');
    });
    await fill(tester);
    await tester.tap(find.byKey(const Key('auth-login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('ログインに失敗しました。しばらく待ってからもう一度お試しください。'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  for (final failure in [false, true]) {
    testWidgets('completion after disposal is safe (failure: $failure)', (
      tester,
    ) async {
      final pending = Completer<void>();
      await open(
        tester,
        ({required email, required password}) => pending.future,
      );
      await fill(tester);
      await tester.tap(find.byKey(const Key('auth-login-submit')));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      if (failure) {
        pending.completeError(
          FirebaseAuthException(code: 'network-request-failed'),
        );
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeScreen), findsNothing);
    });
  }

  testWidgets(
    'welcome opens login and registration/login links replace routes',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
      await tester.ensureVisible(find.byKey(const Key('auth-switch-login')));
      await tester.tap(find.byKey(const Key('auth-switch-login')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('auth-switch-registration')),
      );
      await tester.tap(find.byKey(const Key('auth-switch-registration')));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('auth-switch-login')));
      await tester.tap(find.byKey(const Key('auth-switch-login')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(RegistrationScreen), findsNothing);
      // Sign Up is now the Figma Welcome entry. Switching auth pages replaces
      // the root route instead of keeping a duplicate generic Welcome below.
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
    },
  );

  testWidgets('small viewport and larger text can scroll to login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const LoginScreen(),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('auth-login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-login-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
