import 'dart:convert';

/// The API uses Japanese labels. English keys support the older Issue #4 code.
enum EmotionCategory {
  sad('悲しい', 'sad'),
  lonely('寂しい', 'lonely'),
  anxious('不安', 'anxious'),
  stressed('ストレス', 'stressed'),
  angry('怒り', 'angry'),
  happy('嬉しい', 'happy'),
  calm('安心', 'calm'),
  other('その他', 'other');

  const EmotionCategory(this.japanese, this.englishKey);

  final String japanese;
  final String englishKey;

  static EmotionCategory fromJapanese(Object? value) {
    for (final category in values) {
      if (value == category.japanese) return category;
    }
    // Never include model output or user text in an exception.
    throw const FormatException('Invalid emotion category.');
  }
}

class EmotionAnalysisResult {
  const EmotionAnalysisResult({required this.main, this.secondary})
    : assert(main != secondary);

  final EmotionCategory main;
  final EmotionCategory? secondary;

  /// Missing secondary is accepted and normalized to null; main is mandatory.
  factory EmotionAnalysisResult.fromJsonString(String? text) {
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Missing emotion response.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Invalid emotion JSON.');
    }
    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('main_emotion') ||
        decoded.keys.any(
          (key) => key != 'main_emotion' && key != 'secondary_emotion',
        )) {
      throw const FormatException('Invalid emotion response fields.');
    }
    final main = EmotionCategory.fromJapanese(decoded['main_emotion']);
    final secondary = decoded['secondary_emotion'] == null
        ? null
        : EmotionCategory.fromJapanese(decoded['secondary_emotion']);
    if (main == secondary) {
      throw const FormatException('Emotion categories must be distinct.');
    }
    return EmotionAnalysisResult(main: main, secondary: secondary);
  }

  Map<String, Object?> toJson() => {
    'main_emotion': main.japanese,
    'secondary_emotion': secondary?.japanese,
  };
}
