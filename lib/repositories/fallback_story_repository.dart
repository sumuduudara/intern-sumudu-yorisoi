import '../domain/emotions/emotion_analysis_result.dart';
import '../domain/stories/story.dart';
import 'story_repository.dart';

/// Explicit opt-in. Never conceal permission/configuration errors or replace
/// an empty/withdrawn live catalog with an older offline copy.
class FallbackStoryRepository extends StoryRepository {
  FallbackStoryRepository({required this.primary, required this.offline});
  final StoryRepository primary;
  final StoryRepository offline;

  Future<T> _read<T>(Future<T> Function(StoryRepository) read) async {
    try {
      return await read(primary);
    } on StoryDataException catch (e) {
      if (e.code != StoryDataError.network) rethrow;
      return read(offline);
    }
  }

  @override
  Future<List<Story>> findByEmotion(EmotionCategory mainEmotion) =>
      _read((repository) => repository.findByEmotion(mainEmotion));

  @override
  Future<Story?> findById(String storyId) =>
      _read((repository) => repository.findById(storyId));
}
