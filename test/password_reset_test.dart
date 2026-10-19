import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/login_screen.dart';

const _feedback = '該当するアカウントがある場合は、パスワード再設定メールを送信しました。受信トレイと迷惑メールをご確認ください。';

void main() {
  Future<void> open(
    WidgetTester tester,
    PasswordResetAction action, {
    LoginAction? login,
  }) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(passwordResetAction: action, loginAction: login),
      ),
    );
  }

  testWidgets('reset requires valid email but does not require a password', (
    tester,
  ) async {
    var calls = 0;
    await open(tester, ({required email}) async {
      calls++;
      expect(email, 'student@example.com');
    });
    await tester.tap(find.text('パスワードをお忘れですか？'));
    await tester.pump();
    expect(find.text('メールアドレスを入力してください'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'invalid');
    await tester.tap(find.text('パスワードをお忘れですか？'));
    await tester.pump();
    expect(find.text('正しいメールアドレスを入力してください'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(
      find.byType(TextFormField).first,
      ' student@example.com ',
    );
    await tester.tap(find.text('パスワードをお忘れですか？'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text(_feedback), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsNothing);
  });

  testWidgets('pending reset blocks repeats, login and navigation', (
    tester,
  ) async {
    final pending = Completer<void>();
    var resets = 0;
    var logins = 0;
    await open(
      tester,
      ({required email}) {
        resets++;
        return pending.future;
      },
      login: ({required email, required password}) async {
        logins++;
      },
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'student@example.com',
    );
    await tester.tap(find.text('パスワードをお忘れですか？'));
    await tester.pump();
    expect(find.text('送信中...'), findsOneWidget);
    for (final button in tester.widgetList<TextButton>(
      find.byType(TextButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.enabled, isFalse);
    }
    await tester.tap(find.text('送信中...'));
    await tester.tap(find.text('ログインする'));
    expect(resets, 1);
    expect(logins, 0);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text(_feedback), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('pending login also blocks reset emails', (tester) async {
    final pending = Completer<void>();
    var resets = 0;
    await open(tester, ({required email}) async {
      resets++;
    }, login: ({required email, required password}) => pending.future);
    await tester.enterText(
      find.byType(TextFormField).first,
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'test input');
    await tester.tap(find.text('ログインする'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'パスワードをお忘れですか？'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('パスワードをお忘れですか？'));
    expect(resets, 0);
    pending.complete();
    await tester.pumpAndSettle();
  });

  final errors = {
    'user-not-found': _feedback,
    'invalid-email': '正しいメールアドレスを入力してください。',
    'network-request-failed': '通信に失敗しました。接続を確認して、もう一度お試しください。',
    'too-many-requests': '試行回数が多すぎます。しばらく待ってからお試しください。',
    'operation-not-allowed': '現在、パスワード再設定をご利用いただけません。',
    'unknown': '再設定メールを送信できませんでした。しばらく待ってからもう一度お試しください。',
  };
  for (final entry in errors.entries) {
    testWidgets('reset ${entry.key} gives Japanese feedback and allows retry', (
      tester,
    ) async {
      var calls = 0;
      await open(tester, ({required email}) async {
        calls++;
        if (calls == 1) throw FirebaseAuthException(code: entry.key);
      });
      await tester.enterText(
        find.byType(TextFormField).first,
        'student@example.com',
      );
      await tester.tap(find.text('パスワードをお忘れですか？'));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'パスワードをお忘れですか？'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('パスワードをお忘れですか？'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(_feedback), findsOneWidget);
    });
  }

  testWidgets('unexpected reset failure gives generic feedback', (
    tester,
  ) async {
    await open(tester, ({required email}) async {
      throw StateError('fake failure');
    });
    await tester.enterText(
      find.byType(TextFormField).first,
      'student@example.com',
    );
    await tester.tap(find.text('パスワードをお忘れですか？'));
    await tester.pumpAndSettle();
    expect(
      find.text('再設定メールを送信できませんでした。しばらく待ってからもう一度お試しください。'),
      findsOneWidget,
    );
  });

  for (final failure in [false, true]) {
    testWidgets('reset completion after disposal is safe (failure: $failure)', (
      tester,
    ) async {
      final pending = Completer<void>();
      await open(tester, ({required email}) => pending.future);
      await tester.enterText(
        find.byType(TextFormField).first,
        'student@example.com',
      );
      await tester.tap(find.text('パスワードをお忘れですか？'));
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
