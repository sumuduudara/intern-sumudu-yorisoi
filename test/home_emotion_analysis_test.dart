import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/presentation/screens/emotion_analysis_result_screen.dart';
import 'package:yorisoi/presentation/widgets/home/analysis_loading_view.dart';
import 'package:yorisoi/services/emotion/emotion_analysis_service.dart';

import 'support/fake_emotion_analyzer.dart';

const input = Key('feeling-input');
const submit = Key('share-feeling');
const lonely = EmotionAnalysisResult(main: EmotionCategory.lonely);

class _ResponseModel implements EmotionTextModel {
  const _ResponseModel(this.response);
  final String response;

  @override
  Future<String?> classify(String text) async => response;
}

Future<void> openHome(WidgetTester tester, EmotionAnalyzer service) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: HomeScreen(emotionAnalyzer: service)),
  );
  await tester.pumpAndSettle();
}

Future<void> share(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(input), text);
  await tester.tap(find.byKey(submit));
  await tester.pump();
}

String textOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(input)).controller!.text;

void main() {
  testWidgets('Home uses the actual service and parser with a model fixture', (
    tester,
  ) async {
    await openHome(
      tester,
      EmotionAnalysisService(
        model: const _ResponseModel(
          '{"main_emotion":"寂しい","secondary_emotion":null}',
        ),
      ),
    );
    await share(tester, '今日はひとりで寂しいです');
    await tester.pumpAndSettle();
    expect(find.text('寂しい'), findsOneWidget);
    expect(find.byType(EmotionAnalysisResultScreen), findsOneWidget);
  });

  testWidgets('invalid JSON from the actual service never opens results', (
    tester,
  ) async {
    await openHome(
      tester,
      EmotionAnalysisService(model: const _ResponseModel('not valid JSON')),
    );
    await share(tester, '今日はひとりで寂しいです');
    await tester.pumpAndSettle();
    expect(
      find.text(
        const EmotionAnalysisException(EmotionAnalysisError.invalidResponse)
            .japaneseMessage,
      ),
      findsOneWidget,
    );
    expect(find.byType(EmotionAnalysisResultScreen), findsNothing);
    expect(textOf(tester), '今日はひとりで寂しいです');
  });

  testWidgets(
    'system back cancels the loading display and ignores its late result',
    (tester) async {
      final pending = Completer<EmotionAnalysisResult>();
      await openHome(tester, FakeEmotionAnalyzer((_) => pending.future));
      await share(tester, '寂しいです');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(textOf(tester), '寂しいです');
      pending.complete(lonely);
      await tester.pumpAndSettle();
      expect(find.byType(EmotionAnalysisResultScreen), findsNothing);
    },
  );

  testWidgets('real-mode Home waits for injected service, not a fake delay', (
    tester,
  ) async {
    final pending = Completer<EmotionAnalysisResult>();
    final fake = FakeEmotionAnalyzer((_) => pending.future);
    await openHome(tester, fake);
    const text = '  今日はひとりで寂しいです\n友達に会いたいです  ';
    await share(tester, text);
    expect(fake.inputs, ['今日はひとりで寂しいです\n友達に会いたいです']);
    expect(find.byType(AnalysisLoadingView), findsOneWidget);
    // Preserve the manually corrected heading width and single-line layout.
    final headingFinder = find.text('気持ちを確認しています...');
    expect(tester.widget<Text>(headingFinder).maxLines, 1);
    expect(
      tester
          .widget<Positioned>(
            find
                .ancestor(of: headingFinder, matching: find.byType(Positioned))
                .first,
          )
          .width,
      300,
    );
    expect(tester.getSize(headingFinder).height, closeTo(29, 1));
    expect(find.text('AIで気持ちを確認しています。'), findsOneWidget);
    expect(find.textContaining('UIプレビュー'), findsNothing);
    expect(find.byKey(submit), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(AnalysisLoadingView), findsOneWidget);
    expect(fake.inputs, hasLength(1));
    pending.complete(lonely);
    await tester.pumpAndSettle();
    expect(find.byType(EmotionAnalysisResultScreen), findsOneWidget);
    expect(find.text('寂しい'), findsOneWidget);
    expect(find.byKey(const Key('secondary-emotion')), findsNothing);
    expect(find.text('ペットルームのおすすめは準備中です。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('emotion-result-back')));
    await tester.pumpAndSettle();
    expect(textOf(tester), text);
    expect(tester.widget<TextField>(find.byKey(input)).readOnly, isFalse);
  });

  testWidgets(
    'immediate result displays optional secondary and keeps typed data',
    (tester) async {
      const result = EmotionAnalysisResult(
        main: EmotionCategory.lonely,
        secondary: EmotionCategory.sad,
      );
      await openHome(tester, FakeEmotionAnalyzer((_) async => result));
      await share(tester, '寂しくて悲しいです');
      await tester.pumpAndSettle();
      final screen = tester.widget<EmotionAnalysisResultScreen>(
        find.byType(EmotionAnalysisResultScreen),
      );
      expect(identical(screen.result, result), isTrue);
      expect(find.text('寂しい'), findsOneWidget);
      expect(find.text('悲しい'), findsOneWidget);
      // Chrome must use the bundled Japanese font, not a network fallback.
      for (final text in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(EmotionAnalysisResultScreen),
          matching: find.byType(Text),
        ),
      )) {
        expect(text.style?.fontFamily, 'Zen Maru Gothic');
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(textOf(tester), '寂しくて悲しいです');
    },
  );

  for (final text in ['', ' \n\t', '　']) {
    testWidgets('empty input never calls the service: ${text.codeUnits}', (
      tester,
    ) async {
      final fake = FakeEmotionAnalyzer((_) async => lonely);
      await openHome(tester, fake);
      await share(tester, text);
      expect(fake.inputs, isEmpty);
      expect(find.text('今の気持ちを入力してください。'), findsOneWidget);
      expect(find.byType(AnalysisLoadingView), findsNothing);
    });
  }

  testWidgets('rapid repeated taps create only one request', (tester) async {
    final pending = Completer<EmotionAnalysisResult>();
    final fake = FakeEmotionAnalyzer((_) => pending.future);
    await openHome(tester, fake);
    await tester.enterText(find.byKey(input), '寂しいです');
    final callback = tester.widget<TextButton>(find.byKey(submit)).onPressed!;
    callback();
    callback();
    callback();
    await tester.pump();
    expect(fake.inputs, hasLength(1));
    pending.complete(lonely);
    await tester.pumpAndSettle();
    expect(find.byType(EmotionAnalysisResultScreen), findsOneWidget);
  });

  for (final error in EmotionAnalysisError.values) {
    testWidgets('$error displays safe feedback, keeps text and allows retry', (
      tester,
    ) async {
      var fail = true;
      final fake = FakeEmotionAnalyzer((_) async {
        if (fail) throw EmotionAnalysisException(error);
        return lonely;
      });
      await openHome(tester, fake);
      await share(tester, '  今日はひとりで寂しいです  ');
      await tester.pumpAndSettle();
      expect(
        find.text(EmotionAnalysisException(error).japaneseMessage),
        findsOneWidget,
      );
      expect(textOf(tester), '  今日はひとりで寂しいです  ');
      expect(find.byType(EmotionAnalysisResultScreen), findsNothing);
      fail = false;
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(fake.inputs, hasLength(2));
      expect(find.text('寂しい'), findsOneWidget);
    });
  }

  testWidgets('unknown errors never expose raw backend details', (
    tester,
  ) async {
    await openHome(
      tester,
      FakeEmotionAnalyzer(
        (_) async => throw StateError('private backend detail'),
      ),
    );
    await share(tester, '寂しいです');
    await tester.pumpAndSettle();
    expect(find.textContaining('private backend detail'), findsNothing);
    expect(find.textContaining('接続を確認して'), findsOneWidget);
    expect(textOf(tester), '寂しいです');
  });

  for (final failOld in [false, true]) {
    testWidgets('cancel ignores stale completion (failure: $failOld)', (
      tester,
    ) async {
      final requests = <Completer<EmotionAnalysisResult>>[];
      await openHome(
        tester,
        FakeEmotionAnalyzer((_) {
          final request = Completer<EmotionAnalysisResult>();
          requests.add(request);
          return request.future;
        }),
      );
      await share(tester, '最初の文章');
      await tester.tap(find.text('入力に戻る'));
      await tester.pumpAndSettle();
      expect(textOf(tester), '最初の文章');
      expect(find.textContaining('送信済みの通信は取り消せません'), findsOneWidget);
      await share(tester, '新しい文章');
      if (failOld) {
        requests.first.completeError(
          const EmotionAnalysisException(EmotionAnalysisError.timeout),
        );
      } else {
        requests.first.complete(lonely);
      }
      await tester.pumpAndSettle();
      expect(find.byType(AnalysisLoadingView), findsOneWidget);
      requests.last.complete(
        const EmotionAnalysisResult(main: EmotionCategory.happy),
      );
      await tester.pumpAndSettle();
      expect(find.text('嬉しい'), findsOneWidget);
      expect(find.text('寂しい'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final failure in [false, true]) {
    testWidgets('completion after Home disposal is ignored: $failure', (
      tester,
    ) async {
      final pending = Completer<EmotionAnalysisResult>();
      await openHome(tester, FakeEmotionAnalyzer((_) => pending.future));
      await share(tester, '寂しいです');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      if (failure) {
        pending.completeError(
          const EmotionAnalysisException(EmotionAnalysisError.apiFailure),
        );
      } else {
        pending.complete(lonely);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(EmotionAnalysisResultScreen), findsNothing);
    });
  }

  testWidgets('result fits a small screen and large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: EmotionAnalysisResultScreen(result: lonely),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('emotion-result-back')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('寂しい'), findsOneWidget);
  });

  testWidgets(
    'default Home uses the real service and reports missing Firebase safely',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await share(tester, '今日はひとりで寂しいです');
      await tester.pumpAndSettle();
      expect(find.textContaining('現在、感情分析を利用できません'), findsOneWidget);
      expect(find.text('UIプレビュー'), findsNothing);
      expect(textOf(tester), '今日はひとりで寂しいです');
    },
  );
}
