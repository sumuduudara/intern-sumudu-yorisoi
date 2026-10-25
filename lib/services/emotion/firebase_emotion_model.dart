import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../domain/emotions/emotion_analysis_result.dart';
import 'emotion_analysis_prompt.dart';
import 'emotion_analysis_service.dart';

GenerationConfig emotionGenerationConfig() => GenerationConfig(
  maxOutputTokens: 1024,
  responseMimeType: 'application/json',
  responseSchema: Schema.object(
    properties: {
      'main_emotion': Schema.enumString(
        enumValues: EmotionCategory.values.map((e) => e.japanese).toList(),
      ),
      'secondary_emotion': Schema.enumString(
        enumValues: EmotionCategory.values.map((e) => e.japanese).toList(),
        nullable: true,
      ),
    },
    optionalProperties: ['secondary_emotion'],
  ),
);

/// Lazy initialization: creating this adapter never initializes Firebase or
/// sends a request. main.dart remains the only production bootstrap.
typedef EmotionContentGenerator = Future<GenerateContentResponse> Function(
  Iterable<Content> contents,
);

class FirebaseEmotionModel implements EmotionTextModel {
  FirebaseEmotionModel({this.generateContent});

  final EmotionContentGenerator? generateContent;
  GenerativeModel? _model;

  GenerativeModel _configuredModel() {
    if (Firebase.apps.isEmpty) {
      throw const EmotionAnalysisException(EmotionAnalysisError.configuration);
    }
    return FirebaseAI.googleAI().generativeModel(
      model: emotionModelName,
      systemInstruction: Content.system(emotionSystemPrompt),
      generationConfig: emotionGenerationConfig(),
    );
  }

  @override
  Future<String?> classify(String text) async {
    try {
      final generate =
          generateContent ?? (_model ??= _configuredModel()).generateContent;
      final response = await generate([
        // Keep classification data separate from the system instruction.
        Content.text(jsonEncode({'user_text': text})),
      ]);
      if (response.promptFeedback?.blockReason != null ||
          response.candidates.any(
            (c) =>
                c.finishReason == FinishReason.safety ||
                c.finishReason == FinishReason.recitation,
          )) {
        throw const EmotionAnalysisException(EmotionAnalysisError.blocked);
      }
      if (response.candidates.length != 1 ||
          response.candidates.single.finishReason != FinishReason.stop) {
        throw const EmotionAnalysisException(
          EmotionAnalysisError.invalidResponse,
        );
      }
      return response.text;
    } on EmotionAnalysisException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on QuotaExceeded {
      throw const EmotionAnalysisException(EmotionAnalysisError.quotaExceeded);
    } on InvalidApiKey {
      throw const EmotionAnalysisException(EmotionAnalysisError.configuration);
    } on ServiceApiNotEnabled {
      throw const EmotionAnalysisException(EmotionAnalysisError.configuration);
    } on FirebaseAIException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('genai config not found')) {
        throw const EmotionAnalysisException(
          EmotionAnalysisError.configuration,
        );
      }
      if (message.contains('permission_denied') ||
          message.contains('permission denied') ||
          message.contains('app check') ||
          message.contains('appcheck')) {
        throw const EmotionAnalysisException(
          EmotionAnalysisError.permissionDenied,
        );
      }
      throw const EmotionAnalysisException(EmotionAnalysisError.apiFailure);
    } on FirebaseException catch (error) {
      throw EmotionAnalysisException(
        error.code == 'no-app'
            ? EmotionAnalysisError.configuration
            : EmotionAnalysisError.apiFailure,
      );
    } catch (_) {
      throw const EmotionAnalysisException(EmotionAnalysisError.apiFailure);
    }
  }
}
