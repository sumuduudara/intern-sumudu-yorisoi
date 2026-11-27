import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/stories/story_draft.dart';
import 'package:yorisoi/services/story/firebase_story_model.dart';

GenerateContentResponse response(FinishReason? reason) =>
    GenerateContentResponse([
      Candidate(
        Content.text('{"title":"題名","story_text":"fixture"}'),
        null,
        null,
        reason,
        null,
      ),
    ], null);

void main() {
  Matcher error(StoryGenerationError code) =>
      isA<StoryGenerationException>().having((e) => e.code, 'safe code', code);

  test('story generation has its own output budget and two-field schema', () {
    final config = storyGenerationConfig().toJson();
    expect(config['maxOutputTokens'], 4096);
    expect(config['responseMimeType'], 'application/json');
    final schema = config['responseSchema'] as Map;
    expect(
      (schema['properties'] as Map).keys,
      unorderedEquals(['title', 'story_text']),
    );
    expect(schema['required'], unorderedEquals(['title', 'story_text']));
  });
  test(
    'passes exact resolved prompt to SDK and accepts only complete text',
    () async {
      final model = FirebaseStoryModel(
        generateContent: (contents) async {
          expect(
            (contents.single.parts.single as TextPart).text,
            'resolved prompt',
          );
          return response(FinishReason.stop);
        },
      );
      expect(await model.generate('resolved prompt'), contains('fixture'));
    },
  );
  for (final reason in [FinishReason.maxTokens, FinishReason.other, null]) {
    test('rejects incomplete finish $reason', () async {
      await expectLater(
        FirebaseStoryModel(generateContent: (_) async => response(reason))
            .generate('prompt'),
        throwsA(error(StoryGenerationError.invalidOutput)),
      );
    });
  }
  for (final reason in [FinishReason.safety, FinishReason.recitation]) {
    test('blocked output is not accepted: $reason', () async {
      await expectLater(
        FirebaseStoryModel(generateContent: (_) async => response(reason))
            .generate('prompt'),
        throwsA(error(StoryGenerationError.blocked)),
      );
    });
  }
  test('missing candidates is invalid output', () async {
    await expectLater(
      FirebaseStoryModel(
        generateContent: (_) async => GenerateContentResponse([], null),
      ).generate('prompt'),
      throwsA(error(StoryGenerationError.invalidOutput)),
    );
  });
  for (final entry in <Object, StoryGenerationError>{
    QuotaExceeded('private detail'): StoryGenerationError.quotaExceeded,
    InvalidApiKey('private detail'): StoryGenerationError.configuration,
    ServiceApiNotEnabled('private detail'): StoryGenerationError.configuration,
    FirebaseAIException('Firebase AI Logic genai config not found'):
        StoryGenerationError.genaiConfigurationMissing,
    FirebaseAIException('permission_denied'):
        StoryGenerationError.permissionDenied,
    FirebaseAIException('App Check failure'):
        StoryGenerationError.permissionDenied,
    StateError('private detail'): StoryGenerationError.requestFailed,
  }.entries) {
    test('safe SDK failure mapping: ${entry.value}', () async {
      await expectLater(
        FirebaseStoryModel(generateContent: (_) async => throw entry.key)
            .generate('prompt'),
        throwsA(error(entry.value)),
      );
    });
  }
  test('SDK timeout reaches service boundary', () async {
    await expectLater(
      FirebaseStoryModel(
        generateContent: (_) async => throw TimeoutException('private detail'),
      ).generate('prompt'),
      throwsA(isA<TimeoutException>()),
    );
  });
}
