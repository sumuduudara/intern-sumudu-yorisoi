import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/presentation/screens/welcome_screen.dart';
import 'package:yorisoi/presentation/widgets/home/analysis_loading_view.dart';

import 'support/fake_voice_recognition.dart';

const input = Key('feeling-input');
const mic = Key('home-microphone');
const submit = Key('share-feeling');

Future<void> openHome(
  WidgetTester tester,
  FakeVoiceRecognition fake, {
  Future<void> Function(String)? analysis,
  Future<void> Function()? logout,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(
        voiceRecognition: fake,
        analysisPreviewAction: analysis,
        logoutAction: logout,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(input)).controller!.text;

void main() {
  testWidgets(
    'original mic starts/stops, appends speech, edits, then manually shares',
    (tester) async {
      final fake = FakeVoiceRecognition();
      final submissions = <String>[];
      await openHome(
        tester,
        fake,
        analysis: (value) async => submissions.add(value),
      );
      await tester.enterText(find.byKey(input), '今日は学校に行きました。');
      await tester.tap(find.byKey(mic));
      await tester.pumpAndSettle();
      expect(fake.starts, 1);
      expect(find.byTooltip('音声入力を停止'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(input)).readOnly, isTrue);
      expect(tester.widget<TextButton>(find.byKey(submit)).onPressed, isNull);
      fake.result!('寂しい', false);
      fake.result!('とても寂しいです', false);
      await tester.pump();
      expect(textOf(tester), '今日は学校に行きました。\nとても寂しいです');
      expect(submissions, isEmpty);
      await tester.tap(find.byKey(mic));
      await tester.pump();
      expect(fake.stops, 1);
      expect(tester.widget<IconButton>(find.byKey(mic)).onPressed, isNull);
      fake.result!('とても寂しいです', true);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(input)).readOnly, isFalse);
      expect(find.byTooltip('音声入力を開始'), findsOneWidget);
      expect(submissions, isEmpty);
      await tester.enterText(find.byKey(input), '${textOf(tester)}。');
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();
      expect(submissions, ['今日は学校に行きました。\nとても寂しいです。']);
      expect(find.text('UIプレビュー'), findsOneWidget);
    },
  );

  testWidgets(
    'permission denial preserves input and allows text fallback and retry',
    (tester) async {
      final fake = FakeVoiceRecognition();
      await openHome(tester, fake);
      await tester.enterText(find.byKey(input), '元の気持ち');
      await tester.tap(find.byKey(mic));
      await tester.pumpAndSettle();
      fake.result!('未確定', false);
      fake.error!('not-allowed');
      await tester.pumpAndSettle();
      expect(textOf(tester), '元の気持ち');
      expect(find.textContaining('許可されていません'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(input)).readOnly, isFalse);
      await tester.enterText(find.byKey(input), '文字で修正');
      await tester.pump();
      expect(find.textContaining('許可されていません'), findsNothing);
      await tester.tap(find.byKey(mic));
      await tester.pumpAndSettle();
      expect(fake.starts, 2);
      fake.result!('新しい気持ち', true);
      await tester.pumpAndSettle();
      expect(textOf(tester), '文字で修正\n新しい気持ち');
    },
  );

  testWidgets('double tap while initializing does not start twice', (
    tester,
  ) async {
    final fake = FakeVoiceRecognition()..initialization = Completer<bool>();
    await openHome(tester, fake);
    await tester.tap(find.byKey(mic));
    await tester.pump();
    expect(tester.widget<IconButton>(find.byKey(mic)).onPressed, isNull);
    await tester.tap(find.byKey(mic));
    fake.initialization!.complete(true);
    await tester.pumpAndSettle();
    expect(fake.starts, 1);
    fake.result!('終了', true);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'settings cancels partial speech before logout; auth behavior survives',
    (tester) async {
      final fake = FakeVoiceRecognition();
      var logoutCalls = 0;
      await openHome(
        tester,
        fake,
        logout: () async {
          logoutCalls++;
        },
      );
      await tester.enterText(find.byKey(input), '元の気持ち');
      await tester.tap(find.byKey(mic));
      await tester.pumpAndSettle();
      final oldResult = fake.result!;
      fake.result!('未確定', false);
      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      expect(fake.cancels, 1);
      expect(textOf(tester), '元の気持ち');
      oldResult('遅い結果', true);
      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();
      expect(logoutCalls, 1);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(WelcomeScreen))).canPop(),
        isFalse,
      );
    },
  );

  testWidgets(
    'background cancels; inactive permission dialog does not cancel',
    (tester) async {
      final fake = FakeVoiceRecognition();
      await openHome(tester, fake);
      await tester.enterText(find.byKey(input), '元の気持ち');
      await tester.tap(find.byKey(mic));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(fake.cancels, 0);
      fake.result!('未確定', false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(fake.cancels, 1);
      expect(textOf(tester), '元の気持ち');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fake.starts, 1);
    },
  );

  testWidgets('disposal ignores late speech/error and ends recognition', (
    tester,
  ) async {
    final fake = FakeVoiceRecognition();
    await openHome(tester, fake);
    await tester.tap(find.byKey(mic));
    await tester.pumpAndSettle();
    final oldResult = fake.result!;
    final oldError = fake.error!;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    oldResult('遅い結果', true);
    oldError('network');
    await tester.pumpAndSettle();
    expect(fake.cancels, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('original Figma assets and bounds survive listening at 390x844', (
    tester,
  ) async {
    final fake = FakeVoiceRecognition();
    await openHome(tester, fake);
    final before = tester.getRect(find.byKey(mic));
    await tester.tap(find.byKey(mic));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(mic)), before);
    expect(before.size, const Size(54, 54));
    expect(
      tester.getRect(find.byKey(const Key('feeling-input-card'))),
      const Rect.fromLTWH(20, 338, 350, 268),
    );
    expect(
      tester.getRect(find.byKey(submit)),
      const Rect.fromLTWH(20, 756, 350, 58),
    );
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(assets, contains('assets/images/home/mic_button.png'));
    expect(assets, contains('assets/images/home/pet_group.png'));
    expect(assets, contains('assets/images/home/bg_home.png'));
    expect(find.byType(AnalysisLoadingView), findsNothing);
    expect(tester.takeException(), isNull);
    fake.result!('終了', true);
    await tester.pumpAndSettle();
  });
}
