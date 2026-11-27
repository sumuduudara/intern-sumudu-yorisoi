import 'dart:convert';

import '../emotions/emotion_analysis_result.dart';

enum StoryPet {
  cat('猫'),
  dog('犬'),
  rabbit('うさぎ'),
  dolphin('イルカ');

  const StoryPet(this.japanese);
  final String japanese;
}

class StorySelection {
  StorySelection({required this.emotion, required this.pet}) {
    if (approvedPets[emotion] != pet) {
      throw const StoryGenerationException(StoryGenerationError.invalidPair);
    }
  }

  static const approvedPets = {
    EmotionCategory.sad: StoryPet.cat,
    EmotionCategory.lonely: StoryPet.cat,
    EmotionCategory.anxious: StoryPet.rabbit,
    EmotionCategory.stressed: StoryPet.rabbit,
    EmotionCategory.angry: StoryPet.dog,
    EmotionCategory.happy: StoryPet.dog,
    EmotionCategory.calm: StoryPet.dolphin,
    EmotionCategory.other: StoryPet.dolphin,
  };

  factory StorySelection.fromKeys(String emotion, String pet) {
    final emotions = EmotionCategory.values.where(
      (e) => e.englishKey == emotion || e.japanese == emotion,
    );
    final pets = StoryPet.values.where(
      (p) => p.name == pet || p.japanese == pet,
    );
    if (emotions.isEmpty || pets.isEmpty) {
      throw const StoryGenerationException(StoryGenerationError.invalidPair);
    }
    return StorySelection(emotion: emotions.single, pet: pets.single);
  }

  final EmotionCategory emotion;
  final StoryPet pet;
}

enum StoryGenerationError {
  invalidPair,
  invalidPrompt,
  configuration,
  genaiConfigurationMissing,
  permissionDenied,
  quotaExceeded,
  blocked,
  timeout,
  invalidOutput,
  safetyFlag,
  requestFailed,
}

class StoryGenerationException implements Exception {
  const StoryGenerationException(this.code);
  final StoryGenerationError code;

  String get japaneseMessage => switch (code) {
    StoryGenerationError.invalidPair => '仕様にある感情とペットの組を指定してください。',
    StoryGenerationError.invalidPrompt => '共通Promptの形式または置換項目を確認してください。',
    StoryGenerationError.configuration => 'Firebaseの初期化・API設定を確認してください。',
    StoryGenerationError.genaiConfigurationMissing =>
      'Firebase AI Logic genai config not found：既存projectのAI Logic設定確認が必要です。',
    StoryGenerationError.permissionDenied => 'AIの利用権限・App Check設定を確認してください。',
    StoryGenerationError.quotaExceeded => '利用枠に達しました。自動再送は行いません。',
    StoryGenerationError.blocked => 'AI側で出力が制限されたため、原稿を採用しません。',
    StoryGenerationError.timeout => '生成が時間切れになりました。自動再送は行いません。',
    StoryGenerationError.invalidOutput => '出力形式・日本語・長さを確認できず、原稿を採用しません。',
    StoryGenerationError.safetyFlag => '基本チェックで安全性・形式の問題を検出し、原稿を採用しません。',
    StoryGenerationError.requestFailed => 'AIリクエストに失敗しました。通信・サービスを確認してください。',
  };

  // Never expose raw model output, backend errors or configuration values.
  @override
  String toString() =>
      'StoryGenerationException(${code.name}): $japaneseMessage';
}

class StoryDraft {
  StoryDraft._({
    required this.selection,
    required this.title,
    required this.text,
    required this.characterCount,
    required this.generatedAt,
    required this.warnings,
    this.generationAttempts = 1,
    this.lengthRetryError,
  });

  final StorySelection selection;
  final String title;
  final String text;
  final int characterCount;
  final DateTime generatedAt;
  final List<String> warnings;
  final int generationAttempts;
  final StoryGenerationError? lengthRetryError;

  String get status => 'draft';
  bool get humanApproved => false;
  bool get meetsTargetLength => characterCount >= 600 && characterCount <= 900;

  /// Called only after the single extra generation has completed or failed.
  /// A failed retry retains the original validated draft and safe error code.
  StoryDraft afterLengthRetry({StoryGenerationError? failure}) => StoryDraft._(
    selection: selection,
    title: title,
    text: text,
    characterCount: characterCount,
    generatedAt: generatedAt,
    generationAttempts: 2,
    lengthRetryError: failure,
    warnings: List.unmodifiable([
      ...warnings,
      if (failure != null)
        '長さ調整の追加生成に失敗したため、最初の未承認draftを保持しました'
            '（${failure.name}）。これ以上自動生成しません。'
      else if (!meetsTargetLength)
        '追加生成後も600〜900文字の範囲外です。未承認draftの修正が必要です。'
            'これ以上自動生成しません。',
    ]),
  );

  factory StoryDraft.parse({
    required String? response,
    required StorySelection selection,
    required DateTime generatedAt,
  }) {
    try {
      final decoded = jsonDecode(response ?? '');
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 2 ||
          decoded['title'] is! String ||
          decoded['story_text'] is! String) {
        throw const FormatException();
      }
      final title = (decoded['title'] as String).trim();
      final text = (decoded['story_text'] as String).trim();
      final japanese = RegExp(r'[\u3040-\u30ff\u3400-\u9fff]');
      final count = text
          .replaceAll(RegExp(r'\s', unicode: true), '')
          .runes
          .length;
      if (title.isEmpty ||
          title.runes.length > 80 ||
          count < 100 ||
          count > 2000 ||
          !japanese.hasMatch(title) ||
          !japanese.hasMatch(text) ||
          !text.contains('ぼく')) {
        throw const FormatException();
      }
      final combined = '$title\n$text';
      // A deliberately limited gate, never a substitute for human review.
      final disallowed = RegExp(
        r'https?://|www\.|```|<[^>]+>|^\s*[#*・-]\s|'
        r'うつ病|診断|治療|服薬|薬を|必ず治|気にしすぎ|怒ってはいけない|'
        r'ぼくだけを頼って|いつもあなたを見ている|'
        r'AIza[0-9A-Za-z_-]{35}|-----BEGIN|'
        r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}',
        multiLine: true,
        caseSensitive: false,
      );
      if (disallowed.hasMatch(combined)) {
        throw const StoryGenerationException(StoryGenerationError.safetyFlag);
      }
      return StoryDraft._(
        selection: selection,
        title: title,
        text: text,
        characterCount: count,
        generatedAt: generatedAt.toUtc(),
        warnings: List.unmodifiable([
          if (count < 600 || count > 900) '本文が推奨600〜900文字の範囲外です。加筆・修正が必要です。',
          if (title.runes.length < 8 || title.runes.length > 24)
            'タイトルが推奨8〜24文字の範囲外です。',
          '人による全文・安全性・権利・読み上げ確認と承認が必要です。',
          '音声未生成。2〜3分の実測はしていません。',
        ]),
      );
    } on StoryGenerationException {
      rethrow;
    } on FormatException {
      throw const StoryGenerationException(StoryGenerationError.invalidOutput);
    }
  }
}
