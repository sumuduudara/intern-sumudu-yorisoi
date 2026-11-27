import '../domain/emotions/emotion_analysis_result.dart';
import '../domain/stories/story.dart';

abstract class StoryRepository {
  Future<List<Story>> findByEmotion(EmotionCategory mainEmotion);
  Future<Story?> findById(String storyId);

  Future<List<Story>> findForAnalysis(EmotionAnalysisResult result) =>
      findByEmotion(result.main);
}

enum StoryDataError {
  invalidCatalog,
  readFailed,
  audioCheckFailed,
  network,
  permissionDenied,
  configuration,
}

class StoryDataException implements Exception {
  const StoryDataException(this.code);
  final StoryDataError code;

  @override
  String toString() => 'StoryDataException(${code.name})';
}
