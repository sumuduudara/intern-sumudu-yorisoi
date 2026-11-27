import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/story_firestore_demo.dart';

void main() {
  final check = find.widgetWithText(ElevatedButton, '認証と実Firestore接続を確認');
  ElevatedButton verificationButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('restored session enables verification without reopening login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoryFirestoreDemo(
          authStates: Stream.value(true),
          verifySession: () async => false,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('保存済みセッションあり'), findsOneWidget);
    expect(verificationButton(tester).onPressed, isNotNull);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.text('ログイン済み（再ログイン不要）'), findsOneWidget);
  });

  testWidgets(
    'unknown initial state still permits restoration; duplicate checks blocked',
    (tester) async {
      final states = StreamController<bool>();
      final pending = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StoryFirestoreDemo(
            authStates: states.stream,
            verifySession: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      );
      expect(verificationButton(tester).onPressed, isNotNull);
      await tester.tap(check);
      await tester.tap(check);
      await tester.pump();
      expect(calls, 1);
      expect(verificationButton(tester).onPressed, isNull);
      pending.complete(false);
      await tester.pump();
      expect(verificationButton(tester).onPressed, isNotNull);
      expect(find.textContaining('有効なログイン状態がありません'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      unawaited(states.close());
      await tester.pump();
    },
  );

  testWidgets('auth timeout restores verification button and permits retry', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: StoryFirestoreDemo(
          authStates: Stream.value(true),
          verifySession: () {
            calls++;
            return calls == 1 ? pending.future : Future.value(false);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(check);
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    expect(find.textContaining('時間切れ'), findsOneWidget);
    expect(verificationButton(tester).onPressed, isNotNull);
    await tester.tap(check);
    await tester.pump();
    expect(calls, 2);
    expect(verificationButton(tester).onPressed, isNotNull);
    pending.complete(false);
    await tester.pump();
  });

  testWidgets('auth network error retains known session and re-enables check', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StoryFirestoreDemo(
          authStates: Stream.value(true),
          verifySession: () async =>
              throw FirebaseAuthException(code: 'network-request-failed'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(check);
    await tester.pump();
    expect(find.textContaining('Firebase Authの通信エラー'), findsOneWidget);
    expect(find.textContaining('保存済みセッションあり'), findsOneWidget);
    expect(verificationButton(tester).onPressed, isNotNull);
  });

  testWidgets(
    'auth state changes are reflected without refreshing or signing out',
    (tester) async {
      final states = StreamController<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: StoryFirestoreDemo(
            authStates: states.stream,
            verifySession: () async => false,
          ),
        ),
      );
      states.add(false);
      await tester.pump();
      expect(find.textContaining('ログイン状態：未ログイン'), findsOneWidget);
      states.add(true);
      await tester.pump();
      expect(find.textContaining('保存済みセッションあり'), findsOneWidget);
      states.addError(StateError('test stream failure'));
      await tester.pump();
      expect(find.textContaining('ログイン状態の取得に失敗'), findsOneWidget);
      expect(verificationButton(tester).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
      unawaited(states.close());
      await tester.pump();
    },
  );

  testWidgets('disposing during restoration does not update a removed widget', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: StoryFirestoreDemo(
          authStates: Stream.value(true),
          verifySession: () => pending.future,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(check);
    await tester.pumpWidget(const SizedBox());
    pending.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
