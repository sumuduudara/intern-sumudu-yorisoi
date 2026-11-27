import 'dart:convert';
import 'dart:io';

import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/repositories/json_story_repository.dart';
import 'package:yorisoi/repositories/story_repository.dart';

Future<void> main(List<String> args) async {
  if (args.length > 1) {
    stderr.writeln('使用例：dart run tool/story_data_demo.dart happy');
    exitCode = 64;
    return;
  }
  final input = args.isEmpty ? 'happy' : args.single;
  final matches = EmotionCategory.values.where(
    (e) => e.englishKey == input || e.japanese == input,
  );
  if (matches.isEmpty) {
    stderr.writeln('感情キーまたは日本語カテゴリを指定してください。例：happy / 嬉しい');
    exitCode = 64;
    return;
  }
  final emotion = matches.single;
  final repository = JsonStoryRepository(
    readCatalog: () =>
        File('test/fixtures/story_library_demo.json').readAsString(),
    audioAvailable: (s) async =>
        s.audioUrl?.startsWith('https://example.invalid/fixtures/') ?? false,
  );
  try {
    // Same boundary as Issue #9: only main is used, not user's original text.
    final stories = await repository.findForAnalysis(
      EmotionAnalysisResult(main: emotion),
    );
    stdout.writeln('=== LOCAL FIXTURE DEMO / 本番コンテンツではありません ===');
    stdout.writeln('承認・音声ready・音声の存在確認はfixture上の模擬値です。実音声はありません。');
    stdout.writeln('主感情：${emotion.japanese} / 候補：${stories.length}件');
    for (final s in stories) {
      stdout.writeln(
        jsonEncode({
          'storyId': s.storyId,
          'emotion': s.emotion.japanese,
          'petType': s.petType.japanese,
          'title': s.title,
          'displayOrder': s.displayOrder,
          'durationSeconds': s.duration,
        }),
      );
    }
    if (stories.isEmpty) stdout.writeln('この気持ちの物語は準備中です。');
  } on StoryDataException catch (e) {
    stderr.writeln('読込失敗：${e.code.name}。fixtureの形式・実行場所を確認してください。');
    exitCode = 1;
  }
}
