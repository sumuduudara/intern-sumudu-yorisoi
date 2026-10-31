import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/app/yorisoi_app.dart';
import 'package:yorisoi/presentation/screens/check_email_screen.dart';
import 'package:yorisoi/presentation/screens/forgot_password_screen.dart';
import 'package:yorisoi/presentation/screens/login_screen.dart';
import 'package:yorisoi/presentation/screens/set_new_password_screen.dart';
import 'package:yorisoi/presentation/screens/password_updated_screen.dart';
import 'package:yorisoi/presentation/screens/password_recovery_support.dart';

void main() {
  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester,
    String password,
    String confirmation,
  ) async {
    await tester.enterText(find.byType(TextFormField).at(0), password);
    await tester.enterText(find.byType(TextFormField).at(1), confirmation);
  }

  testWidgets(
    'main app action URL with missing code never bypasses verification',
    (tester) async {
      var restorations = 0;
      await tester.pumpWidget(
        YorisoiApp(
          passwordResetCode: '',
          restoreSession: () async {
            restorations++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SetNewPasswordScreen), findsOneWidget);
      expect(find.text('再設定メール内の有効なリンクから開いてください。'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(restorations, 0);
    },
  );

  testWidgets('waits for verified code before exposing password form', (
    tester,
  ) async {
    final pending = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: SetNewPasswordScreen(
          code: 'fake-test-code',
          verifyCode: (_) => pending.future,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('リンクを確認しています…'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    pending.complete('student@example.com');
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  for (final code in [
    'expired-action-code',
    'invalid-action-code',
    'network-request-failed',
  ]) {
    testWidgets(
      'code verification $code stays outside success and permits retry',
      (tester) async {
        var calls = 0;
        await open(
          tester,
          SetNewPasswordScreen(
            code: 'fake-test-code',
            verifyCode: (_) async {
              calls++;
              if (calls == 1) throw FirebaseAuthException(code: code);
              return 'student@example.com';
            },
          ),
        );
        expect(
          find.text(recoveryError(FirebaseAuthException(code: code))),
          findsOneWidget,
        );
        expect(find.byType(PasswordUpdatedScreen), findsNothing);
        await tester.tap(find.text('リンクの確認を再試行'));
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(find.byType(TextFormField), findsNWidgets(2));
      },
    );
  }

  testWidgets(
    'reset enforces all Figma rules, then prevents duplicate updates',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await open(
        tester,
        SetNewPasswordScreen(
          code: 'fake-test-code',
          verifyCode: (_) async => 'student@example.com',
          confirmReset: ({required code, required password}) {
            expect(code, 'fake-test-code');
            expect(password, 'new-pass123');
            calls++;
            return pending.future;
          },
        ),
      );
      await tester.tap(find.text('パスワードを更新'));
      await tester.pump();
      expect(find.text('新しいパスワードを入力してください'), findsOneWidget);
      await fill(tester, 'abc123', 'different');
      await tester.tap(find.text('パスワードを更新'));
      await tester.pump();
      expect(find.text('パスワードは8文字以上で入力してください'), findsOneWidget);
      expect(find.text('パスワードが一致しません'), findsOneWidget);
      await fill(tester, 'abcdefgh', 'abcdefgh');
      await tester.tap(find.text('パスワードを更新'));
      await tester.pump();
      expect(find.text('英字と数字を組み合わせてください'), findsOneWidget);
      expect(calls, 0);
      await fill(tester, 'new-pass123', 'new-pass123');
      await tester.tap(find.text('パスワードを更新'));
      await tester.pump();
      expect(find.text('更新中...'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('更新中...'));
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(PasswordUpdatedScreen), findsOneWidget);
      await tester.tap(find.text('ログインへ'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
    },
  );

  for (final errorCode in [
    'weak-password',
    'expired-action-code',
    'invalid-action-code',
    'network-request-failed',
    'too-many-requests',
  ]) {
    testWidgets(
      'confirm failure $errorCode never reports success and keeps editable input',
      (tester) async {
        await open(
          tester,
          SetNewPasswordScreen(
            code: 'fake-test-code',
            verifyCode: (_) async => 'student@example.com',
            confirmReset: ({required code, required password}) async {
              throw FirebaseAuthException(code: errorCode);
            },
          ),
        );
        await fill(tester, 'new-pass123', 'new-pass123');
        await tester.tap(find.text('パスワードを更新'));
        await tester.pumpAndSettle();
        expect(
          find.text(recoveryError(FirebaseAuthException(code: errorCode))),
          findsOneWidget,
        );
        expect(find.byType(PasswordUpdatedScreen), findsNothing);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'new-pass123',
        );
      },
    );
  }

  for (final failure in [false, true]) {
    testWidgets('confirmation completing after disposal is safe ($failure)', (
      tester,
    ) async {
      final pending = Completer<void>();
      await open(
        tester,
        SetNewPasswordScreen(
          code: 'fake-test-code',
          verifyCode: (_) async => 'student@example.com',
          confirmReset: ({required code, required password}) => pending.future,
        ),
      );
      await fill(tester, 'new-pass123', 'new-pass123');
      await tester.tap(find.text('パスワードを更新'));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      if (failure) {
        pending.completeError(StateError('private'));
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('resend cooldown, duplicate protection and privacy feedback', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<void>();
    await open(
      tester,
      CheckEmailScreen(
        email: 'student@example.com',
        sendReset: ({required email}) {
          calls++;
          return pending.future;
        },
      ),
    );
    final resend = find.byKey(const Key('auth-resend'));
    await tester.tap(resend);
    expect(calls, 0);
    await tester.pump(const Duration(seconds: 60));
    await tester.tap(resend);
    await tester.pump();
    await tester.tap(resend);
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text(resetEmailFeedback), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.descendant(of: resend, matching: find.byType(TextButton)),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('email launcher failure has a usable manual fallback', (
    tester,
  ) async {
    final resend = Completer<void>();
    await open(
      tester,
      CheckEmailScreen(
        email: 'student@example.com',
        openEmail: () async => false,
        sendReset: ({required email}) => resend.future,
      ),
    );
    await tester.tap(find.text('メールアプリを開く'));
    await tester.pumpAndSettle();
    expect(find.textContaining('メールアプリを開けませんでした。'), findsOneWidget);
    await tester.pump(const Duration(seconds: 60));
    await tester.tap(find.byKey(const Key('auth-resend')));
    await tester.pump();
    expect(find.text('送信中...'), findsOneWidget);
    expect(find.text('メールアプリを開いています…'), findsNothing);
    resend.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('expired link offers a real new-link request screen', (
    tester,
  ) async {
    await open(tester, const SetNewPasswordScreen(code: ''));
    await tester.tap(find.text('リンクをもう一度送る'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  });
}
