import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/login_screen.dart';
import 'package:yorisoi/presentation/screens/forgot_password_screen.dart';
import 'package:yorisoi/presentation/screens/check_email_screen.dart';
import 'package:yorisoi/presentation/screens/password_recovery_support.dart';

const send = Key('auth-send-reset');

void main() {
  Future<void> open(WidgetTester tester, PasswordResetAction action) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: ForgotPasswordScreen(sendReset: action)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reset requires valid email but never requires a password', (
    tester,
  ) async {
    var calls = 0;
    await open(tester, ({required email}) async {
      calls++;
      expect(email, 'student@example.com');
    });
    await tester.tap(find.byKey(send));
    await tester.pump();
    expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.tap(find.byKey(send));
    await tester.pump();
    expect(find.text('正しいメールアドレスを入力してください'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(find.byType(TextFormField), ' student@example.com ');
    await tester.tap(find.byKey(send));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(CheckEmailScreen), findsOneWidget);
    expect(find.textContaining('student@example.com'), findsOneWidget);
    expect(find.text('該当するアカウントがある場合に送信されます。'), findsOneWidget);
  });

  testWidgets('pending reset blocks repeats, fields and navigation', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await open(tester, ({required email}) {
      calls++;
      return pending.future;
    });
    await tester.enterText(find.byType(TextFormField), 'student@example.com');
    await tester.tap(find.byKey(send));
    await tester.pump();
    expect(find.text('送信中...'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
    for (final button in tester.widgetList<TextButton>(
      find.byType(TextButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(send));
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CheckEmailScreen), findsOneWidget);
  });

  testWidgets('pending login blocks opening recovery', (tester) async {
    final pending = Completer<void>();
    var resets = 0;
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          passwordResetAction: ({required email}) async {
            resets++;
          },
          loginAction: ({required email, required password}) => pending.future,
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'test input');
    await tester.tap(find.byKey(const Key('auth-login-submit')));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const Key('auth-forgot-password')),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('auth-forgot-password')));
    expect(resets, 0);
    expect(find.byType(ForgotPasswordScreen), findsNothing);
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('login recovery link preserves typed email', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(passwordResetAction: ({required email}) async {}),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'student@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('auth-forgot-password')));
    await tester.tap(find.byKey(const Key('auth-forgot-password')));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).last)
          .controller!
          .text,
      'student@example.com',
    );
  });

  final errors = [
    'invalid-email',
    'network-request-failed',
    'too-many-requests',
    'operation-not-allowed',
    'unknown',
  ];
  for (final code in errors) {
    testWidgets('reset $code shows Japanese feedback and retries safely', (
      tester,
    ) async {
      var calls = 0;
      await open(tester, ({required email}) async {
        calls++;
        if (calls == 1) throw FirebaseAuthException(code: code);
      });
      await tester.enterText(find.byType(TextFormField), 'student@example.com');
      await tester.tap(find.byKey(send));
      await tester.pumpAndSettle();
      expect(
        find.text(recoveryError(FirebaseAuthException(code: code))),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'student@example.com',
      );
      await tester.tap(find.byKey(send));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(CheckEmailScreen), findsOneWidget);
    });
  }

  testWidgets(
    'unknown address gives the same email screen, not account disclosure',
    (tester) async {
      await open(tester, ({required email}) async {
        throw FirebaseAuthException(code: 'user-not-found');
      });
      await tester.enterText(find.byType(TextFormField), 'student@example.com');
      await tester.tap(find.byKey(send));
      await tester.pumpAndSettle();
      expect(find.byType(CheckEmailScreen), findsOneWidget);
      expect(find.text('該当するアカウントがある場合に送信されます。'), findsOneWidget);
    },
  );

  testWidgets('unexpected reset failure never exposes internal detail', (
    tester,
  ) async {
    await open(tester, ({required email}) async {
      throw StateError('private failure');
    });
    await tester.enterText(find.byType(TextFormField), 'student@example.com');
    await tester.tap(find.byKey(send));
    await tester.pumpAndSettle();
    expect(find.text(recoveryError(StateError('ignored'))), findsOneWidget);
    expect(find.textContaining('private failure'), findsNothing);
  });

  for (final failure in [false, true]) {
    testWidgets('reset completion after disposal is safe ($failure)', (
      tester,
    ) async {
      final pending = Completer<void>();
      await open(tester, ({required email}) => pending.future);
      await tester.enterText(find.byType(TextFormField), 'student@example.com');
      await tester.tap(find.byKey(send));
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
    });
  }
}
