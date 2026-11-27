// Developer-only host demo: real Firebase AI SDK/HTTP/model request.
// Only Firebase Core's native initialization channel is replaced for this
// device-free Flutter test host, exactly as in emotion_analysis_live_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/stories/story_draft.dart';
import 'package:yorisoi/firebase_options.dart';
import 'package:yorisoi/services/emotion/emotion_analysis_prompt.dart';
import 'package:yorisoi/services/story/firebase_story_model.dart';
import 'package:yorisoi/services/story/story_generation_service.dart';

class _DemoCoreHost extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async => CoreInitializeResponse(
    name: appName,
    options: initializeAppRequest,
    pluginConstants: {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const live = bool.fromEnvironment('RUN_LIVE_STORY');

  test(
    'LIVE story generation — developer draft only',
    () async {
      final selection = StorySelection.fromKeys(
        const String.fromEnvironment('STORY_EMOTION'),
        const String.fromEnvironment('STORY_PET'),
      );
      final service = StoryGenerationService(
        model: FirebaseStoryModel(),
        promptDocument: File('docs/story_generation_prompt.md')
            .readAsStringSync(),
      );
      final previousHttp = HttpOverrides.current;
      TestFirebaseCoreHostApi.setUp(_DemoCoreHost());
      HttpOverrides.global = null;
      try {
        try {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
        } catch (_) {
          throw const StoryGenerationException(
            StoryGenerationError.configuration,
          );
        }
        final draft = await service.generate(selection);
        // Only newly generated fictional content and non-secret metadata.
        // No credentials, user input, raw SDK errors or Firebase options.
        // ignore: avoid_print
        print(
          [
            '\n=== Yorisoi Story Demo / 未承認DRAFT ===',
            const JsonEncoder.withIndent('  ').convert({
              'status': draft.status,
              'human_approved': draft.humanApproved,
              'emotion': draft.selection.emotion.japanese,
              'pet': draft.selection.pet.japanese,
              'model': emotionModelName,
              'prompt_version': storyPromptVersion,
              'generated_at': draft.generatedAt.toIso8601String(),
              'character_count': draft.characterCount,
              'length_target_met': draft.meetsTargetLength,
              'generation_attempts': draft.generationAttempts,
              'length_retry_error': draft.lengthRetryError?.name,
              'audio_status': 'not_generated',
              'warnings': draft.warnings,
            }),
            '\n【${draft.title}】\n',
            draft.text,
            '\n未承認・未公開。人の全文確認と承認なしに音声化しないでください。',
          ].join('\n'),
        );
        expect(draft.status, 'draft');
        expect(draft.humanApproved, isFalse);
      } finally {
        HttpOverrides.global = previousHttp;
      }
    },
    skip: !live,
    // Each of the at-most-two requests has the service's 90-second timeout.
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
