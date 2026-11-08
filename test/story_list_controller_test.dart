import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/domain/stories/story.dart';
import 'package:yorisoi/domain/stories/story_draft.dart';
import 'package:yorisoi/presentation/controllers/story_list_controller.dart';
import 'package:yorisoi/repositories/story_repository.dart';

import 'support/fake_story_repository.dart';

void main() {
  for (final emotion in EmotionCategory.values) {
    test(
      'primary ${emotion.name} retains approved pet and ignores secondary',
      () async {
        final repo = FakeStoryRepository(
          items: [storyFixture(emotion: emotion)],
        );
        final result = EmotionAnalysisResult(
          main: emotion,
          secondary: emotion == EmotionCategory.happy
              ? EmotionCategory.sad
              : EmotionCategory.happy,
        );
        final controller = StoryListController(
          result: result,
          findForAnalysis: repo.findForAnalysis,
        );
        addTearDown(controller.dispose);
        await controller.load();
        expect(repo.analyses.single, same(result));
        expect(
          controller.stories.single.petType,
          StorySelection.approvedPets[emotion],
        );
      },
    );
  }
  test(
    'sorts, caps at three and excludes wrong emotion, duplicates and drafts',
    () async {
      final duplicate = storyFixture(number: 9);
      final repo = FakeStoryRepository(
        items: [
          storyFixture(number: 4, order: 4),
          storyFixture(number: 3, order: 3),
          storyFixture(number: 2, order: 2),
          storyFixture(number: 1),
          storyFixture(number: 5, approved: false),
          storyFixture(number: 6, active: false),
          storyFixture(number: 7, audioReady: false),
          storyFixture(emotion: EmotionCategory.sad),
          duplicate,
          duplicate,
        ],
      );
      final c = StoryListController(
        result: const EmotionAnalysisResult(main: EmotionCategory.happy),
        findForAnalysis: repo.findForAnalysis,
      );
      addTearDown(c.dispose);
      await c.load();
      expect(c.stories.map((s) => s.storyId), [
        'happy_dog_001',
        'happy_dog_002',
        'happy_dog_003',
      ]);
      expect(() => c.stories.clear(), throwsUnsupportedError);
    },
  );
  test(
    'deduplicates pending loads and ignores completion after disposal',
    () async {
      final pending = Completer<List<Story>>();
      var reads = 0;
      final c = StoryListController(
        result: const EmotionAnalysisResult(main: EmotionCategory.happy),
        findForAnalysis: (_) {
          reads++;
          return pending.future;
        },
      );
      final loading = c.load();
      await c.load();
      expect(reads, 1);
      c.dispose();
      pending.complete([storyFixture()]);
      await loading;
      expect(c.stories, isEmpty);
    },
  );
  test(
    'network failure is not empty success and supports one manual retry',
    () async {
      var fail = true;
      final c = StoryListController(
        result: const EmotionAnalysisResult(main: EmotionCategory.happy),
        findForAnalysis: (_) async {
          if (fail) throw const StoryDataException(StoryDataError.network);
          return [];
        },
      );
      addTearDown(c.dispose);
      await c.load();
      expect(c.error, StoryDataError.network);
      fail = false;
      await c.load();
      expect(c.error, isNull);
      expect(c.stories, isEmpty);
    },
  );
}
