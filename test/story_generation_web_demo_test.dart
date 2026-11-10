import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/stories/story_draft.dart';
import 'package:yorisoi/story_generation_web_demo.dart';

void main() {
  testWidgets(
    'requires successful attestation before generation; blocks duplicate taps',
    (tester) async {
      final verification = Completer<void>();
      final generation = Completer<StoryDraft>();
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StoryGenerationWebDemo(
            verify: () => verification.future,
            generate: () {
              requests++;
              return generation.future;
            },
          ),
        ),
      );
      final generate = find.text('2. 実Geminiで一話生成（最大2 requests）');
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(
                ElevatedButton,
                '2. 実Geminiで一話生成（最大2 requests）',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('1. App Check接続を確認'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      verification.complete();
      await tester.pump();
      await tester.tap(generate);
      await tester.tap(generate);
      await tester.pump();
      expect(requests, 1);
      generation.completeError(
        const StoryGenerationException(StoryGenerationError.permissionDenied),
      );
      await tester.pump();
      expect(find.textContaining('permissionDenied:'), findsOneWidget);
      expect(find.textContaining('実Gemini応答を検証しました'), findsNothing);
    },
  );

  testWidgets(
    'failed attestation keeps generation disabled and hides raw errors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StoryGenerationWebDemo(
            verify: () async => throw StateError('private diagnostic'),
            generate: () async => throw StateError('must not run'),
          ),
        ),
      );
      await tester.tap(find.text('1. App Check接続を確認'));
      await tester.pump();
      expect(find.textContaining('debug token登録'), findsOneWidget);
      expect(find.textContaining('private diagnostic'), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(
                ElevatedButton,
                '2. 実Geminiで一話生成（最大2 requests）',
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
