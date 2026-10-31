import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/presentation/screens/emotion_analysis_result_screen.dart';
import 'package:yorisoi/presentation/screens/welcome_screen.dart';
import 'package:yorisoi/presentation/widgets/home/analysis_loading_view.dart';

import 'support/fake_voice_recognition.dart';
import 'support/fake_emotion_analyzer.dart';

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
        emotionAnalyzer: FakeEmotionAnalyzer((text) async {
          if (analysis != null) await analysis(text);
          return const EmotionAnalysisResult(main: EmotionCategory.lonely);
        }),
        logoutAction: logout,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String textOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(input)).controller!.text;

bool microphoneIsTinted() => find
    .byKey(const Key('home-microphone-listening-tint'))
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('native early end removes pink state and keeps editable text', (
    tester,
  ) async {
    final fake = FakeVoiceRecognition();
    await openHome(tester, fake);
    await tester.enterText(find.byKey(input), '元の文章');
    await tester.tap(find.byKey(mic));
    await tester.pumpAndSettle();
    expect(microphoneIsTinted(), isTrue);
    fake.result!('寂しいです', false);
    fake.status!('notListening');
    fake.status!('done');
    await tester.pump();
    expect(microphoneIsTinted(), isFalse);
    expect(find.textContaining('聞き取り中'), findsNothing);
    expect(fake.stops, 0);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(textOf(tester), '元の文章\n寂しいです');
    expect(tester.widget<TextField>(find.byKey(input)).readOnly, isFalse);
    expect(tester.widget<TextButton>(find.byKey(submit)).onPressed, isNotNull);
    await tester.enterText(find.byKey(input), '元の文章\n寂しいです。');
    expect(textOf(tester), '元の文章\n寂しいです。');
  });
  for (final listening in [false, true]) {
    testWidgets(
      'microphone has transparent circular edges when listening=$listening',
      (tester) async {
        final fake = FakeVoiceRecognition();
        await openHome(tester, fake);
        if (listening) {
          await tester.tap(find.byKey(mic));
          await tester.pumpAndSettle();
        }
        final artworkFinder = find.byKey(const Key('home-microphone-artwork'));
        final artwork = tester.widget<Image>(artworkFinder);
        await tester.runAsync(
          () => precacheImage(artwork.image, tester.element(artworkFinder)),
        );
        await tester.pumpAndSettle();
        final circle = tester.widget<ClipOval>(
          find.byKey(const Key('home-microphone-circle')),
        );
        // Render the actual Home artwork on transparency, without the card
        // behind it. This catches the original PNG's nontransparent corners.
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(width: 54, height: 54, child: circle),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            boundaryKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba,
            ))!;
            var opaqueWhite = 0;
            var opaqueColor = 0;
            for (var y = 0; y < image.height; y++) {
              for (var x = 0; x < image.width; x++) {
                final i = (y * image.width + x) * 4;
                final alpha = pixels.getUint8(i + 3);
                // Allow the one-pixel antialiasing fringe, but no pixels in
                // the rectangular corners or outside the circular silhouette.
                final dx = x + 0.5 - 54;
                final dy = y + 0.5 - 54;
                if (dx * dx + dy * dy > 55 * 55) {
                  expect(alpha, 0, reason: 'outside circle at ($x, $y)');
                }
                if (alpha != 255) continue;
                final r = pixels.getUint8(i);
                final g = pixels.getUint8(i + 1);
                final b = pixels.getUint8(i + 2);
                if (r == 255 && g == 255 && b == 255) opaqueWhite++;
                if (listening
                    ? r > g + 10 && r > b + 10
                    : b > r + 10 && b > g + 10) {
                  opaqueColor++;
                }
              }
            }
            expect(opaqueWhite, greaterThan(0));
            expect(opaqueColor, greaterThan(0));
            expect(pixels.getUint8((54 * image.width + 54) * 4 + 3), 255);
          } finally {
            image.dispose();
          }
        });
      },
    );
  }
  testWidgets(
    'listening tint preserves PNG alpha and white microphone artwork',
    (tester) async {
      final fake = FakeVoiceRecognition();
      await openHome(tester, fake);
      final idleArtwork = tester.widget<Image>(
        find.byKey(const Key('home-microphone-artwork')),
      );
      expect(idleArtwork.color, isNull);
      expect(microphoneIsTinted(), isFalse);

      await tester.tap(find.byKey(mic));
      await tester.pumpAndSettle();
      final filter = tester.widget<ColorFiltered>(
        find.byKey(const Key('home-microphone-listening-tint')),
      );
      expect(
        tester
            .widget<Image>(find.byKey(const Key('home-microphone-artwork')))
            .color,
        isNull,
      );

      await tester.runAsync(() async {
        final data = await rootBundle.load('assets/images/home/mic_button.png');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final original = (await codec.getNextFrame()).image;
        codec.dispose();
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawImage(
          original,
          Offset.zero,
          ui.Paint()..colorFilter = filter.colorFilter,
        );
        final picture = recorder.endRecording();
        final tinted = await picture.toImage(original.width, original.height);
        try {
          final before = (await original.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          final after = (await tinted.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          var transparentPixels = 0;
          var whitePixels = 0;
          var pinkPixels = 0;
          for (var i = 0; i < before.lengthInBytes; i += 4) {
            // Every pixel must retain its original transparency, including the
            // rectangular PNG canvas outside the circle and its soft shadow.
            expect(after.getUint8(i + 3), before.getUint8(i + 3));
            if (before.getUint8(i + 3) == 0) transparentPixels++;
            if (before.getUint8(i + 3) != 255) continue;
            final r = before.getUint8(i);
            final g = before.getUint8(i + 1);
            final b = before.getUint8(i + 2);
            if (r == 255 && g == 255 && b == 255) {
              expect(after.getUint8(i), 255);
              expect(after.getUint8(i + 1), 255);
              expect(after.getUint8(i + 2), 255);
              whitePixels++;
            }
            if (b > r + 20 && b > g + 10) {
              expect(after.getUint8(i), greaterThan(after.getUint8(i + 1)));
              expect(after.getUint8(i), greaterThan(after.getUint8(i + 2)));
              pinkPixels++;
            }
          }
          expect(transparentPixels, greaterThan(0));
          expect(whitePixels, greaterThan(0));
          expect(pinkPixels, greaterThan(0));
        } finally {
          original.dispose();
          tinted.dispose();
          picture.dispose();
        }
      });

      fake.result!('とても寂しいです', true);
      await tester.pumpAndSettle();
      expect(microphoneIsTinted(), isFalse);
      expect(
        tester
            .widget<Image>(find.byKey(const Key('home-microphone-artwork')))
            .image,
        idleArtwork.image,
      );
    },
  );

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
      expect(microphoneIsTinted(), isFalse);
      await tester.enterText(find.byKey(input), '今日は学校に行きました。');
      await tester.tap(find.byKey(mic));
      await tester.pumpAndSettle();
      expect(fake.starts, 1);
      expect(microphoneIsTinted(), isTrue);
      expect(find.textContaining('聞き取り中'), findsOneWidget);
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
      expect(microphoneIsTinted(), isFalse);
      expect(find.textContaining('聞き取り中'), findsNothing);
      expect(textOf(tester), '今日は学校に行きました。\nとても寂しいです');
      expect(tester.widget<IconButton>(find.byKey(mic)).onPressed, isNull);
      fake.result!('とても寂しいです', true);
      await tester.pumpAndSettle();
      expect(microphoneIsTinted(), isFalse);
      expect(textOf(tester), '今日は学校に行きました。\nとても寂しいです');
      expect(tester.widget<TextField>(find.byKey(input)).readOnly, isFalse);
      expect(find.byTooltip('音声入力を開始'), findsOneWidget);
      expect(submissions, isEmpty);
      await tester.enterText(find.byKey(input), '${textOf(tester)}。');
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();
      expect(submissions, ['今日は学校に行きました。\nとても寂しいです。']);
      expect(find.byType(EmotionAnalysisResultScreen), findsOneWidget);
      expect(find.text('寂しい'), findsOneWidget);
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
      expect(microphoneIsTinted(), isFalse);
      expect(find.textContaining('聞き取り中'), findsNothing);
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
    expect(microphoneIsTinted(), isFalse);
    expect(tester.widget<IconButton>(find.byKey(mic)).onPressed, isNull);
    await tester.tap(find.byKey(mic));
    fake.initialization!.complete(true);
    await tester.pumpAndSettle();
    expect(fake.starts, 1);
    expect(microphoneIsTinted(), isTrue);
    fake.result!('終了', true);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'listening color waits for actual status, not permissions or listen call',
    (tester) async {
      final fake = FakeVoiceRecognition()
        ..initialization = Completer<bool>()
        ..emitListening = false;
      await openHome(tester, fake);
      await tester.tap(find.byKey(mic));
      await tester.pump();
      expect(microphoneIsTinted(), isFalse);
      expect(find.text('音声入力を準備しています。'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(microphoneIsTinted(), isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      fake.initialization!.complete(true);
      await tester.pumpAndSettle();
      expect(fake.starts, 1);
      expect(microphoneIsTinted(), isFalse);
      expect(find.textContaining('聞き取り中'), findsNothing);

      fake.status!('listening');
      await tester.pump();
      expect(microphoneIsTinted(), isTrue);
      expect(find.textContaining('聞き取り中'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(find.byKey(const Key('home-microphone-state'))),
          matchesSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasToggledState: true,
            isToggled: true,
            hasTapAction: true,
            tooltip: '音声入力を停止',
          ),
        );
      } finally {
        semantics.dispose();
      }
      fake.result!('確認しました', true);
      await tester.pumpAndSettle();
      expect(microphoneIsTinted(), isFalse);
    },
  );

  testWidgets('failed preparation never shows listening color', (tester) async {
    final fake = FakeVoiceRecognition()..ready = false;
    await openHome(tester, fake);
    await tester.enterText(find.byKey(input), '元の文章');
    await tester.tap(find.byKey(mic));
    await tester.pumpAndSettle();
    expect(fake.starts, 0);
    expect(microphoneIsTinted(), isFalse);
    expect(find.textContaining('聞き取り中'), findsNothing);
    expect(find.textContaining('利用できません'), findsOneWidget);
    expect(textOf(tester), '元の文章');
    expect(tester.widget<TextField>(find.byKey(input)).readOnly, isFalse);
  });

  testWidgets(
    'repeated stop taps stay idle-colored and restart only after final result',
    (tester) async {
      final fake = FakeVoiceRecognition();
      await openHome(tester, fake);
      await tester.tap(find.byKey(mic));
      await tester.pumpAndSettle();
      fake.result!('とても寂しいです', false);
      await tester.tap(find.byKey(mic));
      await tester.pump();
      expect(microphoneIsTinted(), isFalse);
      expect(find.text('音声を確認しています。'), findsOneWidget);
      await tester.tap(find.byKey(mic));
      await tester.tap(find.byKey(mic));
      await tester.pump();
      expect(fake.starts, 1);
      expect(fake.stops, 1);
      expect(microphoneIsTinted(), isFalse);
      expect(tester.widget<TextButton>(find.byKey(submit)).onPressed, isNull);
      fake.result!('とても寂しいです', true);
      await tester.pumpAndSettle();
      expect(textOf(tester), 'とても寂しいです');
      expect(tester.widget<TextField>(find.byKey(input)).readOnly, isFalse);
      expect(
        tester.widget<TextButton>(find.byKey(submit)).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(mic));
      await tester.pumpAndSettle();
      expect(fake.starts, 2);
      expect(microphoneIsTinted(), isTrue);
      fake.error!('network');
      await tester.pumpAndSettle();
      expect(microphoneIsTinted(), isFalse);
      expect(textOf(tester), 'とても寂しいです');
      expect(find.textContaining('聞き取り中'), findsNothing);
    },
  );

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
