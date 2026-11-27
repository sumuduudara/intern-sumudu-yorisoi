import 'dart:convert';

import '../domain/emotions/emotion_analysis_result.dart';
import '../domain/stories/story.dart';
import 'story_repository.dart';

/// No Firebase, publication writes, generation, or UI dependencies.
class JsonStoryRepository extends StoryRepository {
  JsonStoryRepository({
    required this.readCatalog,
    required this.audioAvailable,
  });

  final Future<String> Function() readCatalog;
  // Required: production callers must check asset existence or an approved
  // remote-media manifest. The fixture demo explicitly simulates this check.
  final Future<bool> Function(Story story) audioAvailable;

  Future<List<Story>> _readEligible() async {
    final String source;
    try {
      source = await readCatalog();
    } catch (_) {
      throw const StoryDataException(StoryDataError.readFailed);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const StoryDataException(StoryDataError.invalidCatalog);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const StoryDataException(StoryDataError.invalidCatalog);
    }
    if ((decoded.containsKey('schema_version') &&
            decoded.containsKey('schemaVersion')) ||
        (decoded.containsKey('publication_status') &&
            decoded.containsKey('publicationStatus'))) {
      throw const StoryDataException(StoryDataError.invalidCatalog);
    }
    final legacy = decoded['schema_version'] == 'yorisoi-story-library-v1';
    if ((!legacy && decoded['schemaVersion'] != 'yorisoi-story-data-v1') ||
        decoded['language'] != 'ja-JP' ||
        decoded['stories'] is! List) {
      throw const StoryDataException(StoryDataError.invalidCatalog);
    }
    final publication =
        decoded[legacy ? 'publication_status' : 'publicationStatus'];
    if (publication == 'draft') return [];
    if (publication != 'approved') {
      throw const StoryDataException(StoryDataError.invalidCatalog);
    }
    final parsed = <Story>[];
    for (final raw in decoded['stories'] as List) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        parsed.add(legacy ? Story.fromLibraryJson(raw) : Story.fromJson(raw));
      } on FormatException {
        // Never expose malformed data, raw content or unapproved fallback.
        continue;
      }
    }
    final counts = <String, int>{};
    for (final s in parsed) {
      counts.update(s.storyId, (n) => n + 1, ifAbsent: () => 1);
    }
    // Ambiguous IDs (including different revisions) are all excluded.
    return parsed
        .where((s) => counts[s.storyId] == 1 && s.isPublishable)
        .toList();
  }

  Future<bool> _hasAudio(Story story) async {
    try {
      return await audioAvailable(story);
    } catch (_) {
      // A verifier outage is not an empty library and never bypasses gating.
      throw const StoryDataException(StoryDataError.audioCheckFailed);
    }
  }

  @override
  Future<List<Story>> findByEmotion(EmotionCategory mainEmotion) async {
    final matches =
        (await _readEligible()).where((s) => s.emotion == mainEmotion).toList()
          ..sort((a, b) {
            final order = a.displayOrder.compareTo(b.displayOrder);
            return order != 0 ? order : a.storyId.compareTo(b.storyId);
          });
    final result = <Story>[];
    for (final story in matches) {
      if (await _hasAudio(story)) result.add(story);
      if (result.length == 3) break;
    }
    return List.unmodifiable(result);
  }

  @override
  Future<Story?> findById(String storyId) async {
    for (final s in await _readEligible()) {
      if (s.storyId == storyId) return await _hasAudio(s) ? s : null;
    }
    return null;
  }
}
