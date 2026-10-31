import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../domain/stories/story_draft.dart';
import '../emotion/emotion_analysis_prompt.dart';
import 'story_generation_service.dart';

typedef StoryContentGenerator = Future<GenerateContentResponse> Function(
  Iterable<Content> contents,
);

GenerationConfig storyGenerationConfig() => GenerationConfig(
  maxOutputTokens: 4096,
  responseMimeType: 'application/json',
  responseSchema: Schema.object(
    properties: {'title': Schema.string(), 'story_text': Schema.string()},
  ),
);

/// Developer-only caller. The normal app never instantiates this adapter.
class FirebaseStoryModel implements StoryTextModel {
  FirebaseStoryModel({this.generateContent});

  final StoryContentGenerator? generateContent;

  @override
  Future<String?> generate(String prompt) async {
    try {
      final generate = generateContent ?? _configuredModel().generateContent;
      final response = await generate([Content.text(prompt)]);
      if (response.promptFeedback?.blockReason != null ||
          response.candidates.any(
            (c) =>
                c.finishReason == FinishReason.safety ||
                c.finishReason == FinishReason.recitation,
          )) {
        throw const StoryGenerationException(StoryGenerationError.blocked);
      }
      if (response.candidates.length != 1 ||
          response.candidates.single.finishReason != FinishReason.stop) {
        throw const StoryGenerationException(
          StoryGenerationError.invalidOutput,
        );
      }
      return response.text;
    } on StoryGenerationException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on QuotaExceeded {
      throw const StoryGenerationException(StoryGenerationError.quotaExceeded);
    } on InvalidApiKey {
      throw const StoryGenerationException(StoryGenerationError.configuration);
    } on ServiceApiNotEnabled {
      throw const StoryGenerationException(StoryGenerationError.configuration);
    } on FirebaseAIException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('genai config not found')) {
        throw const StoryGenerationException(
          StoryGenerationError.genaiConfigurationMissing,
        );
      }
      if (message.contains('permission') ||
          message.contains('app check') ||
          message.contains('appcheck')) {
        throw const StoryGenerationException(
          StoryGenerationError.permissionDenied,
        );
      }
      throw const StoryGenerationException(StoryGenerationError.requestFailed);
    } on FirebaseException {
      throw const StoryGenerationException(StoryGenerationError.configuration);
    } catch (_) {
      throw const StoryGenerationException(StoryGenerationError.requestFailed);
    }
  }

  GenerativeModel _configuredModel() {
    if (Firebase.apps.isEmpty) {
      throw const StoryGenerationException(StoryGenerationError.configuration);
    }
    return FirebaseAI.googleAI().generativeModel(
      model: emotionModelName,
      generationConfig: storyGenerationConfig(),
    );
  }
}
