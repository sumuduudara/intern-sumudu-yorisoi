import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/emotions/emotion_analysis_result.dart';
import '../../domain/stories/story.dart';
import '../../domain/stories/story_draft.dart';
import '../../repositories/story_repository.dart';

/// Read-only presentation state; no Firebase, routing or generation API here.
class StoryListController extends ChangeNotifier {
  StoryListController({required this.result, required this.findForAnalysis});

  final EmotionAnalysisResult result;
  final Future<List<Story>> Function(EmotionAnalysisResult) findForAnalysis;
  List<Story> stories = const [];
  bool loading = false;
  StoryDataError? error;
  bool _disposed = false;

  Future<void> load() async {
    if (_disposed || loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final found = await findForAnalysis(result)
          .timeout(const Duration(seconds: 20));
      if (_disposed) return;
      // Defence in depth. The repository owns release/audio-existence checks.
      final counts = <String, int>{};
      for (final story in found) {
        counts.update(story.storyId, (count) => count + 1, ifAbsent: () => 1);
      }
      final eligible =
          found
              .where(
                (story) =>
                    story.emotion == result.main &&
                    story.petType == StorySelection.approvedPets[result.main] &&
                    story.isPublishable &&
                    story.audioPath != null &&
                    story.audioUrl == null &&
                    counts[story.storyId] == 1,
              )
              .toList()
            ..sort((a, b) {
              final order = a.displayOrder.compareTo(b.displayOrder);
              return order == 0 ? a.storyId.compareTo(b.storyId) : order;
            });
      stories = List.unmodifiable(eligible.take(3));
    } on TimeoutException {
      if (!_disposed) error = StoryDataError.network;
    } on StoryDataException catch (failure) {
      if (!_disposed) error = failure.code;
    } catch (_) {
      if (!_disposed) error = StoryDataError.readFailed;
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
