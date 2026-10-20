import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/app/yorisoi_app.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/presentation/screens/welcome_screen.dart';

void main() {
  testWidgets('waits for restoration before showing protected home', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(YorisoiApp(restoreSession: () => pending.future));
    expect(find.text('ログイン状態を確認中...'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsNothing);
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
      isFalse,
    );
  });

  testWidgets('missing or invalid saved session shows welcome', (tester) async {
    await tester.pumpWidget(YorisoiApp(restoreSession: () async => false));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('restoration error stays outside home and retries once on tap', (
    tester,
  ) async {
    var calls = 0;
    final retry = Completer<bool>();
    await tester.pumpWidget(
      YorisoiApp(
        restoreSession: () {
          calls++;
          if (calls == 1) throw StateError('temporary failure');
          return retry.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ログイン状態を確認できませんでした。接続を確認してください。'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await tester.tap(find.text('再試行'));
    await tester.pump();
    expect(find.text('ログイン状態を確認中...'), findsOneWidget);
    expect(find.text('再試行'), findsNothing);
    retry.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('restoration completing after disposal is safe', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(YorisoiApp(restoreSession: () => pending.future));
    await tester.pumpWidget(const SizedBox());
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
