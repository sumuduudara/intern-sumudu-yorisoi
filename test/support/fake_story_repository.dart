import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/domain/stories/story.dart';
import 'package:yorisoi/domain/stories/story_draft.dart';
import 'package:yorisoi/repositories/story_repository.dart';

/// Test-only metadata. No fixture is bundled into the app or published.
Story storyFixture({
  EmotionCategory emotion = EmotionCategory.happy,
  int number = 1,
  int order = 1,
  bool active = true,
  bool approved = true,
  bool audioReady = true,
}) {
  final pet = StorySelection.approvedPets[emotion]!;
  final suffix = number.toString().padLeft(3, '0');
  return Story.fromJson({
    'storyId': '${emotion.englishKey}_${pet.name}_$suffix',
    'emotion': emotion.englishKey,
    'petType': pet.name,
    'title': 'テスト用のお話$suffix',
    'description': 'これは自動テスト専用の説明です。',
    'storyText': 'ぼくのテスト用のお話です。公開する原稿ではありません。',
    'audioPath':
        'assets/audio/${emotion.englishKey}/${pet.name}/story_$suffix.mp3',
    'audioUrl': null,
    'imageUrl': null,
    'duration': audioReady ? 150 : null,
    'isActive': active,
    'createdAt': '2026-11-08T00:00:00Z',
    'language': 'ja-JP',
    'revision': 1,
    'approvalStatus': approved ? 'approved_text' : 'draft',
    'humanApproved': approved,
    'audioStatus': audioReady ? 'ready' : 'not_generated',
    'audioSourceRevision': audioReady ? 1 : null,
    'displayOrder': order,
  });
}

class FakeStoryRepository extends StoryRepository {
  FakeStoryRepository({this.items = const [], this.read});
  List<Story> items;
  Future<List<Story>> Function()? read;
  final List<EmotionAnalysisResult> analyses = [];
  @override
  Future<List<Story>> findForAnalysis(EmotionAnalysisResult result) {
    analyses.add(result);
    return read?.call() ?? Future.value(items);
  }

  @override
  Future<List<Story>> findByEmotion(EmotionCategory mainEmotion) async => items;
  @override
  Future<Story?> findById(String storyId) async => null;
}
