// Developer-only localhost entrypoint. Never connected to the product UI.
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'domain/stories/story_draft.dart';
import 'firebase_options.dart';
import 'services/story/firebase_story_model.dart';
import 'services/story/story_generation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb ||
      !kDebugMode ||
      !const bool.fromEnvironment('YORISOI_APP_CHECK_DEBUG') ||
      !const {
        'localhost',
        '127.0.0.1',
        '::1',
        '[::1]',
      }.contains(Uri.base.host)) {
    runApp(
      const MaterialApp(home: Scaffold(body: Text('localhost Web debug専用です。'))),
    );
    return;
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    await FirebaseAppCheck.instance.activate(providerWeb: WebDebugProvider());
    final prompt = await rootBundle.loadString(
      'docs/story_generation_prompt.md',
    );
    final service = StoryGenerationService(
      model: FirebaseStoryModel(),
      promptDocument: prompt,
    );
    final selection = StorySelection.fromKeys(
      const String.fromEnvironment('STORY_EMOTION', defaultValue: 'lonely'),
      const String.fromEnvironment('STORY_PET', defaultValue: 'cat'),
    );
    runApp(
      MaterialApp(
        home: StoryGenerationWebDemo(
          verify: () async {
            // A successful exchange proves this browser's debug token is trusted.
            // Never print, display or persist the returned attestation token.
            final token = await FirebaseAppCheck.instance.getToken(true);
            if (token == null || token.isEmpty) {
              throw StateError('No attestation');
            }
          },
          generate: () => service.generate(selection),
        ),
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(body: Text('開発demoの初期化に失敗しました。local設定・指定した組を確認してください。')),
      ),
    );
  }
}

class StoryGenerationWebDemo extends StatefulWidget {
  const StoryGenerationWebDemo({
    super.key,
    required this.verify,
    required this.generate,
  });
  final Future<void> Function() verify;
  final Future<StoryDraft> Function() generate;

  @override
  State<StoryGenerationWebDemo> createState() => _StoryGenerationWebDemoState();
}

class _StoryGenerationWebDemoState extends State<StoryGenerationWebDemo> {
  bool _busy = false;
  bool _verified = false;
  StoryDraft? _draft;
  String _message = '最初にApp Checkを確認してください。生成は自動実行しません。';

  Future<void> _run({required bool generation}) async {
    if (_busy || (generation && !_verified)) return;
    setState(() {
      _busy = true;
    });
    try {
      if (generation) {
        final draft = await widget.generate();
        if (!mounted) return;
        setState(() {
          _draft = draft;
          _message = '実Gemini応答を検証しました。未承認DRAFTです。';
        });
      } else {
        await widget.verify();
        if (!mounted) return;
        setState(() {
          _verified = true;
          _message = 'App Check: server token exchange成功。次に生成できます。';
        });
      }
    } on StoryGenerationException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = '${error.code.name}: ${error.japaneseMessage}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!generation) _verified = false;
        _message = 'App Check/接続の確認に失敗しました。同じブラウザーのdebug token登録を確認してください。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Issue #10 制作用・未承認story demo')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('App利用者向けではありません。保存・公開・音声生成は行いません。'),
          ElevatedButton(
            onPressed: _busy ? null : () => _run(generation: false),
            child: const Text('1. App Check接続を確認'),
          ),
          ElevatedButton(
            onPressed: _busy || !_verified
                ? null
                : () => _run(generation: true),
            child: const Text('2. 実Geminiで一話生成（最大2 requests）'),
          ),
          if (_busy) const LinearProgressIndicator(),
          SelectableText(_message),
          if (_draft case final draft?) ...[
            SelectableText(
              'status: ${draft.status}\nhuman_approved: ${draft.humanApproved}\nemotion: ${draft.selection.emotion.japanese}\npet: ${draft.selection.pet.japanese}\ncharacter_count: ${draft.characterCount}\nlength_target_met: ${draft.meetsTargetLength}\ngeneration_attempts: ${draft.generationAttempts}\nlength_retry_error: ${draft.lengthRetryError?.name}\nprompt_version: $storyPromptVersion',
            ),
            SelectableText(draft.title),
            SelectableText(draft.text),
            for (final warning in draft.warnings) Text(warning),
          ],
        ],
      ),
    ),
  );
}
