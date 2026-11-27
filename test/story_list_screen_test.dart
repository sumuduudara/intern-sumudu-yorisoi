import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/domain/stories/story.dart';
import 'package:yorisoi/presentation/screens/story_list_screen.dart';
import 'package:yorisoi/presentation/screens/story_selection_handoff_screen.dart';
import 'package:yorisoi/presentation/screens/home_screen.dart';
import 'package:yorisoi/repositories/json_story_repository.dart';
import 'package:yorisoi/repositories/story_repository.dart';

import 'support/fake_story_repository.dart';
import 'support/fake_emotion_analyzer.dart';

const happy = EmotionAnalysisResult(
  main: EmotionCategory.happy,
  secondary: EmotionCategory.lonely,
);

Future<void> openList(
  WidgetTester tester,
  StoryRepository repo, {
  OpenStory? open,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: StoryListScreen(result: happy, repository: repo, openStory: open),
    ),
  );
  await tester.pump();
}

void main() {
  for (final width in [320.0, 390.0, 520.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'empty-state text remains separated and wraps at width $width / scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: StoryListScreen(
                  result: const EmotionAnalysisResult(
                    main: EmotionCategory.stressed,
                    secondary: EmotionCategory.anxious,
                  ),
                  repository: FakeStoryRepository(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Rect bounds(String key) => tester.getRect(find.byKey(Key(key)));
          expect(
            bounds('story-pet-description').top - bounds('main-emotion').bottom,
            greaterThanOrEqualTo(11.9),
          );
          expect(
            bounds('story-emotion-disclaimer').top -
                bounds('secondary-emotion').bottom,
            greaterThanOrEqualTo(15.9),
          );
          expect(
            bounds('story-state-panel').top -
                bounds('story-emotion-panel').bottom,
            greaterThanOrEqualTo(23.9),
          );
          expect(
            bounds('story-list-empty-detail').top -
                bounds('story-list-empty').bottom,
            greaterThanOrEqualTo(11.9),
          );
          for (final key in [
            'story-pet-description',
            'story-emotion-disclaimer',
            'story-list-empty',
            'story-list-empty-detail',
          ]) {
            final finder = find.byKey(Key(key));
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(tester.widget<Text>(finder).maxLines, isNull);
            final panel = key.startsWith('story-list-')
                ? bounds('story-state-panel')
                : bounds('story-emotion-panel');
            expect(bounds(key).left, greaterThanOrEqualTo(panel.left + 19.9));
            expect(bounds(key).right, lessThanOrEqualTo(panel.right - 19.9));
          }
          final panel = tester.widget<Container>(
            find
                .descendant(
                  of: find.byKey(const Key('story-emotion-panel')),
                  matching: find.byType(Container),
                )
                .first,
          );
          expect((panel.decoration as BoxDecoration).color, Colors.white);
          await tester.ensureVisible(find.text('もう一度確認'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('temporary-story-list')), findsOneWidget);
        },
      );
    }
  }
  testWidgets(
    'Home analysis hands the same result to repository and returns with input intact',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeStoryRepository(items: [storyFixture()]);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            emotionAnalyzer: FakeEmotionAnalyzer((_) async => happy),
            storyRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('feeling-input')),
        '今日はとても楽しいです',
      );
      await tester.tap(find.byKey(const Key('share-feeling')));
      await tester.pumpAndSettle();
      expect(find.byType(StoryListScreen), findsOneWidget);
      expect(repo.analyses.single, same(happy));
      final select = find.byKey(const ValueKey('select-happy_dog_001'));
      await tester.ensureVisible(select);
      await tester.tap(select);
      await tester.pumpAndSettle();
      expect(find.byType(StorySelectionHandoffScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('feeling-input')))
            .controller!
            .text,
        '今日はとても楽しいです',
      );
    },
  );
  testWidgets(
    'loads repository, then cards expose real metadata and original pet asset',
    (tester) async {
      final pending = Completer<List<Story>>();
      final repo = FakeStoryRepository(read: () => pending.future);
      await openList(tester, repo);
      expect(find.byKey(const Key('story-list-loading')), findsOneWidget);
      expect(find.text('仮UI・正式なFigmaデザイン待ち'), findsOneWidget);
      expect(repo.analyses.single, same(happy));
      pending.complete([storyFixture()]);
      await tester.pumpAndSettle();
      expect(find.text('テスト用のお話001'), findsOneWidget);
      expect(find.text('2分30秒'), findsOneWidget);
      expect(find.text('現在ご案内できるお話は1件です。'), findsOneWidget);
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .where(
              (image) =>
                  image.image == const AssetImage('assets/images/pets/dog.png'),
            ),
        hasLength(2),
      );
    },
  );

  testWidgets(
    'selection retains actual ID/revision in honest future-player handoff',
    (tester) async {
      await openList(
        tester,
        FakeStoryRepository(items: [storyFixture(number: 2)]),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('select-happy_dog_002'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final screen = tester.widget<StorySelectionHandoffScreen>(
        find.byType(StorySelectionHandoffScreen),
      );
      expect(screen.request.storyId, 'happy_dog_002');
      expect(screen.request.revision, 1);
      expect(find.textContaining('音声は再生していません'), findsOneWidget);
      await tester.tap(find.text('お話一覧に戻る'));
      await tester.pumpAndSettle();
      expect(find.byType(StoryListScreen), findsOneWidget);
    },
  );

  testWidgets('repeated selections invoke navigation only once while pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    var opens = 0;
    await openList(
      tester,
      FakeStoryRepository(items: [storyFixture()]),
      open: (_, request) {
        opens++;
        expect(request.storyId, 'happy_dog_001');
        return pending.future;
      },
    );
    await tester.pumpAndSettle();
    final callback = tester
        .widget<TextButton>(find.byKey(const ValueKey('select-happy_dog_001')))
        .onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(opens, 1);
    pending.completeError(StateError('private navigation detail'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private navigation'), findsNothing);
    expect(find.byKey(const Key('story-selection-error')), findsOneWidget);
  });

  testWidgets(
    'real JSON repository draft gate produces empty UI, never fake cards',
    (tester) async {
      final fixture = jsonDecode(
        File('test/fixtures/story_library_demo.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      fixture['publicationStatus'] = 'draft';
      var audioChecks = 0;
      final repo = JsonStoryRepository(
        readCatalog: () async => jsonEncode(fixture),
        audioAvailable: (_) async {
          audioChecks++;
          return true;
        },
      );
      await openList(tester, repo);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('story-list-empty')), findsOneWidget);
      expect(find.text('このお話を選ぶ'), findsNothing);
      expect(audioChecks, 0);
    },
  );

  for (final code in StoryDataError.values) {
    testWidgets(
      '$code is safe, distinguishable from empty and manually retryable',
      (tester) async {
        var fail = true;
        final repo = FakeStoryRepository(
          read: () async {
            if (fail) throw StoryDataException(code);
            return [];
          },
        );
        await openList(tester, repo);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('story-list-error')), findsOneWidget);
        expect(find.byKey(const Key('story-list-empty')), findsNothing);
        fail = false;
        await tester.tap(find.text('再試行'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('story-list-empty')), findsOneWidget);
        expect(repo.analyses, hasLength(2));
      },
    );
  }

  testWidgets('slow read times out; disposal ignores late result', (
    tester,
  ) async {
    final pending = Completer<List<Story>>();
    await openList(tester, FakeStoryRepository(read: () => pending.future));
    await tester.pump(const Duration(seconds: 21));
    expect(find.byKey(const Key('story-list-error')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pending.complete([storyFixture()]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'list fits narrow viewport with doubled text and long descriptions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: StoryListScreen(
              result: happy,
              repository: FakeStoryRepository(items: [storyFixture()]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('select-happy_dog_001')),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
