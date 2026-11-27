import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/services/emotion/emotion_analysis_service.dart';

class _Model implements EmotionTextModel {
  _Model(this.answer);
  final Future<String?> Function(String text) answer;
  final inputs = <String>[];

  @override
  Future<String?> classify(String text) {
    inputs.add(text);
    return answer(text);
  }
}

Matcher hasCode(EmotionAnalysisError code) => isA<EmotionAnalysisException>()
    .having((error) => error.code, 'safe error code', code);

void main() {
  // These are injected output fixtures, NOT evidence of live AI accuracy.
  const examples = {
    '今日はひとりで寂しいです': EmotionCategory.lonely,
    '明日のことが心配です': EmotionCategory.anxious,
    '今日はとても楽しいです': EmotionCategory.happy,
  };
  for (final entry in examples.entries) {
    test('Japanese input and mocked JSON fixture: ${entry.key}', () async {
      final model = _Model(
        (_) async => '{"main_emotion":"${entry.value.japanese}"}',
      );
      final result = await EmotionAnalysisService(model: model)
          .analyze(entry.key);
      expect(model.inputs, [entry.key]);
      expect(result.main, entry.value);
      expect(result.secondary, isNull);
    });
  }

  for (final input in ['', ' \t\n', '　']) {
    test(
      'empty/whitespace input makes no model call: ${input.codeUnits}',
      () async {
        final model = _Model((_) async => '{}');
        await expectLater(
          EmotionAnalysisService(model: model).analyze(input),
          throwsA(hasCode(EmotionAnalysisError.emptyInput)),
        );
        expect(model.inputs, isEmpty);
      },
    );
  }

  test('trims edges but preserves Japanese and internal newlines', () async {
    final model = _Model(
      (_) async => '{"main_emotion":"寂しい","secondary_emotion":"悲しい"}',
    );
    final result = await EmotionAnalysisService(model: model)
        .analyze('  寂しいです\n友達に会いたい  ');
    expect(model.inputs.single, '寂しいです\n友達に会いたい');
    expect(result.secondary, EmotionCategory.sad);
  });

  for (final response in <String?>[
    null,
    '',
    '{',
    '{"main_emotion":"unknown"}',
  ]) {
    test(
      'invalid output becomes invalidResponse, never other: $response',
      () async {
        final model = _Model((_) async => response);
        await expectLater(
          EmotionAnalysisService(model: model).analyze('気持ち'),
          throwsA(hasCode(EmotionAnalysisError.invalidResponse)),
        );
        expect(model.inputs, hasLength(1));
      },
    );
  }

  for (final code in EmotionAnalysisError.values) {
    test(
      'safe error $code propagates once and has Japanese feedback',
      () async {
        final model = _Model((_) async => throw EmotionAnalysisException(code));
        await expectLater(
          EmotionAnalysisService(model: model).analyze('気持ち'),
          throwsA(hasCode(code)),
        );
        expect(model.inputs, hasLength(1));
        final error = EmotionAnalysisException(code);
        expect(error.japaneseMessage, isNotEmpty);
        expect(error.toString(), contains(code.name));
      },
    );
  }

  test(
    'unexpected API failure is safe and is not automatically retried',
    () async {
      final model = _Model(
        (_) async => throw StateError('private token and input'),
      );
      try {
        await EmotionAnalysisService(model: model).analyze('気持ち');
        fail('Expected API failure');
      } on EmotionAnalysisException catch (error) {
        expect(error.code, EmotionAnalysisError.apiFailure);
        expect(error.toString(), isNot(contains('private')));
        expect(error.japaneseMessage, isNot(contains('private')));
      }
      expect(model.inputs, hasLength(1));
    },
  );

  testWidgets(
    'timeout returns no result; late success cannot become a result',
    (tester) async {
      final pending = Completer<String?>();
      final model = _Model((_) => pending.future);
      final service = EmotionAnalysisService(
        model: model,
        timeout: const Duration(seconds: 1),
      );
      final expectation = expectLater(
        service.analyze('気持ち'),
        throwsA(hasCode(EmotionAnalysisError.timeout)),
      );
      await tester.pump(const Duration(seconds: 1));
      await expectation;
      pending.complete('{"main_emotion":"寂しい"}');
      await tester.pump();
      expect(model.inputs, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  test('nonpositive timeout is rejected', () {
    expect(
      () => EmotionAnalysisService(
        model: _Model((_) async => null),
        timeout: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}
