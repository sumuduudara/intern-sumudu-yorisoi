import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/presentation/widgets/home/analysis_loading_view.dart';

import 'support/fake_voice_recognition.dart';

const input = Key('feeling-input');
const submit = Key('share-feeling');

Future<void> openHome(WidgetTester tester, {HomeScreen? screen}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: screen ?? const HomeScreen()));
  await tester.pumpAndSettle();
}

Future<void> share(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(input), text);
  await tester.tap(find.byKey(submit));
  await tester.pump();
}

void main() {
  testWidgets('390x844 uses CSS card and action bounds with original assets', (
    tester,
  ) async {
    await openHome(tester, screen: const HomeScreen(displayName: 'Sumudu'));
    expect(find.text('こんばんは、Sumuduさん'), findsOneWidget);
    expect(find.text('Good evening, Sumudu'), findsOneWidget);
    expect(find.text('今日はどんな気分ですか？'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('feeling-input-card'))),
      const Rect.fromLTWH(20, 338, 350, 268),
    );
    expect(
      tester.getRect(find.byKey(submit)),
      const Rect.fromLTWH(20, 756, 350, 58),
    );
    final images = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(images, contains('assets/images/home/bg_home.png'));
    expect(images, contains('assets/images/home/pet_group.png'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing display name does not expose an email or sample name', (
    tester,
  ) async {
    await openHome(tester);
    expect(find.text('こんばんは'), findsOneWidget);
    expect(find.textContaining('Sumudu'), findsNothing);
  });

  for (final text in ['', '  \n\t', '　']) {
    testWidgets('empty/whitespace input is not submitted: ${text.codeUnits}', (
      tester,
    ) async {
      var calls = 0;
      await openHome(
        tester,
        screen: HomeScreen(
          analysisPreviewAction: (_) async {
            calls++;
          },
        ),
      );
      await share(tester, text);
      expect(find.text('今の気持ちを入力してください。'), findsOneWidget);
      expect(find.byType(AnalysisLoadingView), findsNothing);
      expect(calls, 0);
      await tester.enterText(find.byKey(input), '寂しいです');
      await tester.pump();
      expect(find.text('今の気持ちを入力してください。'), findsNothing);
    });
  }

  testWidgets(
    'multiline text opens distinct loading preview and blocks duplicates',
    (tester) async {
      final pending = Completer<void>();
      final calls = <String>[];
      await openHome(
        tester,
        screen: HomeScreen(
          analysisPreviewAction: (text) {
            calls.add(text);
            return pending.future;
          },
        ),
      );
      await share(tester, '  今日は寂しいです。\n友達に会いたいです。  ');
      expect(calls, ['今日は寂しいです。\n友達に会いたいです。']);
      expect(find.byType(AnalysisLoadingView), findsOneWidget);
      expect(find.byKey(submit), findsNothing);
      expect(find.text('UIプレビュー：AI分析・おすすめ画面は未接続です。'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('home-settings')))
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(calls, hasLength(1));
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('UIプレビュー'), findsOneWidget);
      expect(find.textContaining('入力内容は送信していません。'), findsOneWidget);
      await tester.tap(find.text('入力に戻る'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(input)).controller!.text,
        '  今日は寂しいです。\n友達に会いたいです。  ',
      );
    },
  );

  testWidgets('default preview finishes without a Firebase initialization', (
    tester,
  ) async {
    await openHome(tester);
    await share(tester, '寂しいです');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('UIプレビュー'), findsOneWidget);
    expect(find.textContaining('感情分析・おすすめ画面はまだ接続されていません。'), findsOneWidget);
  });

  testWidgets('preview failure keeps input and supports retry', (tester) async {
    var calls = 0;
    await openHome(
      tester,
      screen: HomeScreen(
        analysisPreviewAction: (_) async {
          calls++;
          if (calls == 1) throw StateError('private internal detail');
        },
      ),
    );
    await share(tester, '不安です');
    await tester.pumpAndSettle();
    expect(find.text('プレビューの表示に失敗しました。もう一度お試しください。'), findsOneWidget);
    expect(find.textContaining('private internal detail'), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(input)).controller!.text,
      '不安です',
    );
    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('UIプレビュー'), findsOneWidget);
  });

  testWidgets(
    'cancel ignores an older request completing during a new preview',
    (tester) async {
      final requests = <Completer<void>>[];
      await openHome(
        tester,
        screen: HomeScreen(
          analysisPreviewAction: (_) {
            final pending = Completer<void>();
            requests.add(pending);
            return pending.future;
          },
        ),
      );
      await share(tester, '寂しいです');
      await tester.tap(find.text('入力に戻る'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(submit));
      await tester.pump();
      requests.first.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AnalysisLoadingView), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      requests.last.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  for (final failure in [false, true]) {
    testWidgets('preview after disposal is safe (failure: $failure)', (
      tester,
    ) async {
      final pending = Completer<void>();
      await openHome(
        tester,
        screen: HomeScreen(analysisPreviewAction: (_) => pending.future),
      );
      await share(tester, '寂しいです');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      if (failure) {
        pending.completeError(StateError('fake failure'));
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets(
    'unavailable microphone falls back; settings retains preview limits',
    (tester) async {
      await openHome(
        tester,
        screen: HomeScreen(
          previewOnly: true,
          voiceRecognition: FakeVoiceRecognition()..ready = false,
        ),
      );
      await tester.tap(find.byKey(const Key('home-microphone')));
      await tester.pumpAndSettle();
      expect(find.text('音声入力を利用できません。文字で入力してください。'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      expect(find.text('設定プレビュー'), findsOneWidget);
      expect(find.text('UIプレビューのためログアウトは利用できません。'), findsOneWidget);
      expect(find.text('ログアウト'), findsNothing);
    },
  );

  testWidgets('small viewport can scroll to submit without render overflow', (
    tester,
  ) async {
    await openHome(
      tester,
      screen: HomeScreen(analysisPreviewAction: (_) async {}),
    );
    tester.view.physicalSize = const Size(320, 480);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(input), '嬉しいです');
    await tester.ensureVisible(find.byKey(submit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(submit));
    await tester.pumpAndSettle();
    expect(find.text('UIプレビュー'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
