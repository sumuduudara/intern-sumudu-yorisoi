import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/domain/stories/story.dart';
import 'package:yorisoi/domain/stories/story_draft.dart';
import 'package:yorisoi/presentation/screens/story_list_screen.dart';
import 'package:yorisoi/presentation/widgets/stories/story_choice_card.dart';
import 'package:yorisoi/presentation/widgets/stories/story_list_design.dart';

import 'support/fake_story_repository.dart';

void main() {
  for (final emotion in EmotionCategory.values) {
    for (final empty in [false, true]) {
      testWidgets('official pet assets for ${emotion.name}, empty=$empty', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeStoryRepository(
          items: empty
              ? []
              : [
                  storyFixture(emotion: emotion),
                  storyFixture(emotion: emotion, number: 2),
                  storyFixture(emotion: emotion, number: 3),
                  storyFixture(emotion: emotion, number: 4, approved: false),
                ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: StoryListScreen(
              result: EmotionAnalysisResult(
                main: emotion,
                secondary: emotion == EmotionCategory.other
                    ? EmotionCategory.sad
                    : EmotionCategory.other,
              ),
              repository: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final pet = StorySelection.approvedPets[emotion]!;
        final imageNames = tester
            .widgetList<Image>(find.byType(Image))
            .map((image) => (image.image as AssetImage).assetName)
            .toList();
        final extension = pet == StoryPet.cat ? 'jpg' : 'png';
        expect(
          imageNames,
          contains('assets/images/story_list/bg_${pet.name}.$extension'),
        );
        expect(
          imageNames,
          contains('assets/images/story_list/pet_${pet.name}.png'),
        );
        expect(imageNames.any((name) => name.contains('/home/')), isFalse);
        expect(find.byKey(const Key('temporary-story-list')), findsNothing);
        expect(find.byType(StoryChoiceCard), findsNWidgets(empty ? 0 : 3));
        if (empty) {
          expect(imageNames, contains('${storyAssetPath}empty_moon.png'));
          expect(find.text('いま公開されているおはなしはありません。'), findsOneWidget);
        } else {
          expect(find.text('Choose a story · 3'), findsOneWidget);
          expect(find.text('テスト用のお話004'), findsNothing);
          expect(find.text('約2分 · 2:30'), findsNWidgets(3));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('long metadata reflows at 320px and doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = storyFixture().toJson()
      ..['title'] = 'ゆっくり歩きながら見つけた小さな花とあたたかい午後のおはなし'
      ..['description'] = '少し長い説明でも、日本語を切り捨てずに読めるように折り返します。お話の内容を確認してから選べます。';
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: StoryListScreen(
          result: const EmotionAnalysisResult(main: EmotionCategory.happy),
          repository: FakeStoryRepository(items: [Story.fromJson(record)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final text in [record['title'], record['description']]) {
      final finder = find.text(text as String);
      expect(
        tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
        isFalse,
      );
    }
    final button = find.byKey(const ValueKey('select-happy_dog_001'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);
  });

  testWidgets('reference back and speech bubble origins remain 390x844', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: StoryListScreen(
          result: const EmotionAnalysisResult(main: EmotionCategory.lonely),
          repository: FakeStoryRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('story-list-back'))).topLeft,
      const Offset(18, 54),
    );
    expect(
      tester.getRect(find.byKey(const Key('story-speech-bubble'))).topLeft,
      const Offset(168, 128),
    );
    expect(tester.takeException(), isNull);
  });
}
