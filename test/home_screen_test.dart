import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/presentation/screens/welcome_screen.dart';

Future<void> tapLogout(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('home-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ログアウト'));
}

void main() {
  testWidgets('logout waits, prevents duplicate taps and clears old routes', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    Navigator.of(tester.element(find.byType(WelcomeScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(
          logoutAction: () {
            calls++;
            return pending.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapLogout(tester);
    await tester.pump();
    expect(find.text('ログアウト中...'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('share-feeling')))
          .onPressed,
      isNull,
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.text('ログアウト中...'));
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(WelcomeScreen))).canPop(),
      isFalse,
    );
  });

  testWidgets(
    'failed logout stays home, shows Japanese feedback and can retry',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            logoutAction: () async {
              calls++;
              if (calls == 1) throw StateError('fake failure');
            },
          ),
        ),
      );
      await tapLogout(tester);
      await tester.pumpAndSettle();
      expect(find.text('ログアウトできませんでした。もう一度お試しください。'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      await tapLogout(tester);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(calls, 2);
    },
  );

  for (final failure in [false, true]) {
    testWidgets('logout after disposal is safe (failure: $failure)', (
      tester,
    ) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(logoutAction: () => pending.future)),
      );
      await tapLogout(tester);
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      if (failure) {
        pending.completeError(StateError('fake failure'));
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeScreen), findsNothing);
    });
  }
}
