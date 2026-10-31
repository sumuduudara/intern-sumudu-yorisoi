import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';

void main() {
  const categories = {
    '悲しい': 'sad',
    '寂しい': 'lonely',
    '不安': 'anxious',
    'ストレス': 'stressed',
    '怒り': 'angry',
    '嬉しい': 'happy',
    '安心': 'calm',
    'その他': 'other',
  };

  test('exactly the eight agreed categories and legacy English keys', () {
    expect(EmotionCategory.values, hasLength(8));
    expect({
      for (final e in EmotionCategory.values) e.japanese: e.englishKey,
    }, categories);
  });

  for (final entry in categories.entries) {
    test('${entry.key} is accepted as main and serializes to Japanese', () {
      final result = EmotionAnalysisResult.fromJsonString(
        jsonEncode({'main_emotion': entry.key, 'secondary_emotion': null}),
      );
      expect(result.main.japanese, entry.key);
      expect(result.main.englishKey, entry.value);
      expect(result.secondary, isNull);
      expect(result.toJson(), {
        'main_emotion': entry.key,
        'secondary_emotion': null,
      });
    });

    test('${entry.key} is accepted as a distinct secondary category', () {
      final main = entry.key == '寂しい' ? '悲しい' : '寂しい';
      final result = EmotionAnalysisResult.fromJsonString(
        jsonEncode({'main_emotion': main, 'secondary_emotion': entry.key}),
      );
      expect(result.secondary?.japanese, entry.key);
    });
  }

  test('missing secondary is normalized to explicit null', () {
    final result = EmotionAnalysisResult.fromJsonString(
      ' {"main_emotion":"寂しい"}\n',
    );
    expect(result.secondary, isNull);
    expect(result.toJson(), {'main_emotion': '寂しい', 'secondary_emotion': null});
  });

  final invalid = <String?, String>{
    null: 'null response',
    '': 'empty response',
    ' \n ': 'blank response',
    '{}': 'missing main',
    '{"secondary_emotion":"悲しい"}': 'secondary only',
    '{"main_emotion":null}': 'null main',
    '{"main_emotion":"lonely"}': 'English main',
    '{"main_emotion":"寂しい "}': 'category whitespace',
    '{"main_emotion":"孤独"}': 'unknown synonym',
    '{"main_emotion":"calm/relieved"}': 'English alias',
    '{"main_emotion":8}': 'number main',
    '{"main_emotion":true}': 'boolean main',
    '{"main_emotion":["寂しい"]}': 'list main',
    '{"main_emotion":"寂しい","secondary_emotion":""}': 'empty secondary',
    '{"main_emotion":"寂しい","secondary_emotion":"sad"}': 'English secondary',
    '{"main_emotion":"寂しい","secondary_emotion":{}}': 'object secondary',
    '{"main_emotion":"寂しい","secondary_emotion":false}': 'boolean secondary',
    '{"main_emotion":"寂しい","secondary_emotion":"寂しい"}': 'duplicate emotions',
    '{"main_emotion":"寂しい","diagnosis":"private detail"}': 'extra property',
    '[{"main_emotion":"寂しい"}]': 'array root',
    '"寂しい"': 'string root',
    'true': 'boolean root',
    'null': 'null root',
    '```json\n{"main_emotion":"寂しい"}\n```': 'Markdown fence',
    '{"main_emotion":"寂しい",}': 'trailing comma',
    '{"main_emotion":': 'truncated JSON',
    '{"main_emotion":"寂しい"} explanation': 'appended explanation',
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.value} without echoing raw response', () {
      try {
        EmotionAnalysisResult.fromJsonString(entry.key);
        fail('Expected invalid response to be rejected');
      } on FormatException catch (error) {
        expect(error.source, isNull);
        expect(error.toString(), isNot(contains('private detail')));
      }
    });
  }
}
