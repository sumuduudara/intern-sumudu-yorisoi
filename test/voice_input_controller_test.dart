import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/presentation/controllers/voice_input_controller.dart';
import 'package:yorisoi/services/voice/speech_to_text_service.dart';

import 'support/fake_voice_recognition.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'Japanese locale uses native ID; web never relies on browser catalogue',
    () {
      expect(japaneseVoiceLocale(['en_US', 'ja_JP'], isWeb: false), 'ja_JP');
      expect(japaneseVoiceLocale(['JA-jp'], isWeb: false), 'JA-jp');
      expect(
        japaneseVoiceLocale(['en-US', 'ja-CN', 'jargon'], isWeb: false),
        isNull,
      );
      expect(japaneseVoiceLocale([], isWeb: true), 'ja-JP');
      expect(japaneseVoiceLocale(['en-US'], isWeb: true), 'ja-JP');
    },
  );

  late TextEditingController text;
  late FakeVoiceRecognition fake;
  late VoiceInputController voice;

  setUp(() {
    text = TextEditingController(text: '  元の文章。\n');
    fake = FakeVoiceRecognition();
    voice = VoiceInputController(textController: text, recognition: fake);
  });

  tearDown(() {
    voice.dispose();
    text.dispose();
  });

  test(
    'partials replace only this utterance; final commits once and is editable',
    () async {
      await voice.toggle();
      expect(fake.selectedLocale, 'ja_JP');
      expect(voice.phase, VoiceInputPhase.listening);
      fake.result!('とても', false);
      expect(text.text, '  元の文章。\nとても');
      fake.result!('とても寂しいです', false);
      expect(text.text, '  元の文章。\nとても寂しいです');
      fake.result!('とても寂しいです', true);
      fake.result!('重複', true);
      fake.status!('done');
      await flush();
      expect(text.text, '  元の文章。\nとても寂しいです');
      expect(voice.busy, isFalse);
      expect(fake.cancels, 1);
      text.text += '。';
      expect(text.text, endsWith('寂しいです。'));
      expect(voice.error, isNull);
    },
  );

  for (final original in ['', '元の文章', '元の文章\n']) {
    test(
      'one newline separator only for nonempty prior text: ${original.length}',
      () async {
        text.text = original;
        await voice.toggle();
        fake.result!('こんにちは', true);
        await flush();
        expect(text.text, original.isEmpty ? 'こんにちは' : '元の文章\nこんにちは');
      },
    );
  }

  test('web attempts ja-JP without querying installed locales', () async {
    voice.dispose();
    voice = VoiceInputController(
      textController: text,
      recognition: fake,
      isWeb: true,
    );
    await voice.toggle();
    expect(fake.selectedLocale, 'ja-JP');
    expect(fake.localeQueries, 0);
  });

  test(
    'initialization blocks duplicates and cancellation prevents late listening',
    () async {
      fake.initialization = Completer<bool>();
      final pending = voice.toggle();
      await voice.toggle();
      expect(voice.phase, VoiceInputPhase.preparing);
      final cancelling = voice.cancel();
      fake.initialization!.complete(true);
      await pending;
      await cancelling;
      expect(fake.starts, 0);
      expect(text.text, '  元の文章。\n');
      expect(voice.busy, isFalse);
    },
  );

  test(
    'unavailable initialization is not falsely labelled permission denied',
    () async {
      fake.ready = false;
      await voice.toggle();
      await flush();
      expect(fake.starts, 0);
      expect(voice.error, '音声入力を利用できません。文字で入力してください。');
      expect(voice.busy, isFalse);
      expect(text.text, '  元の文章。\n');
    },
  );

  test('no Japanese locale falls back without listening in English', () async {
    fake.installedLocales = ['en-US'];
    await voice.toggle();
    await flush();
    expect(fake.starts, 0);
    expect(voice.error, contains('日本語'));
    expect(voice.busy, isFalse);
  });

  for (final code in [
    'not-allowed',
    'error_permission',
    'error_speech_timeout',
    'error_no_match',
    'network',
    'language-not-supported',
    'audio-capture',
    'error_busy',
    'private exception details',
  ]) {
    test('$code preserves text and allows manual retry', () async {
      await voice.toggle();
      fake.result!('未確定', false);
      fake.error!(code);
      await flush();
      expect(
        text.text,
        ['error_speech_timeout', 'error_no_match'].contains(code)
            ? '  元の文章。\n未確定'
            : '  元の文章。\n',
      );
      expect(voice.error, contains('文字'));
      expect(voice.error, isNot(contains('private exception details')));
      expect(voice.busy, isFalse);
      await voice.toggle();
      expect(fake.starts, 2);
    });
  }

  test(
    'stop waits for final result; notListening alone does not discard partial',
    () async {
      await voice.toggle();
      fake.result!('寂しいです', false);
      fake.status!('notListening');
      await flush();
      expect(voice.phase, VoiceInputPhase.stopping);
      expect(fake.stops, 0);
      await voice.toggle();
      expect(fake.starts, 1);
      fake.result!('寂しいです', true);
      await flush();
      expect(voice.busy, isFalse);
      expect(text.text, endsWith('寂しいです'));
    },
  );

  testWidgets('done without speech and empty final return unchanged input', (
    tester,
  ) async {
    await voice.toggle();
    fake.status!('done');
    await tester.pump(const Duration(seconds: 3));
    expect(text.text, '  元の文章。\n');
    expect(voice.error, contains('認識できません'));
    await voice.toggle();
    fake.result!('  ', true);
    await tester.pump();
    expect(text.text, '  元の文章。\n');
    expect(voice.busy, isFalse);
  });

  test('late old result/status/error cannot overwrite a new session', () async {
    await voice.toggle();
    final oldResult = fake.result!;
    final oldStatus = fake.status!;
    final oldError = fake.error!;
    await voice.cancel();
    text.text = '編集した文章';
    await voice.toggle();
    oldResult('古い結果', true);
    oldStatus('done');
    oldError('network');
    fake.result!('新しい結果', true);
    await flush();
    expect(text.text, '編集した文章\n新しい結果');
    expect(voice.error, isNull);
  });

  testWidgets('native early done accepts late final without a second stop', (
    tester,
  ) async {
    await voice.toggle();
    fake.result!('とても', false);
    fake.status!('notListening');
    fake.status!('done');
    expect(voice.phase, VoiceInputPhase.stopping);
    expect(fake.stops, 0);
    await tester.pump(const Duration(seconds: 1));
    await voice.toggle();
    expect(fake.starts, 1);
    fake.result!('とても寂しいです', true);
    await tester.pump();
    expect(voice.busy, isFalse);
    expect(text.text, '  元の文章。\nとても寂しいです');
    expect(voice.error, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(fake.cancels, 1);
  });

  testWidgets('native early stop retains partial when no final arrives', (
    tester,
  ) async {
    await voice.toggle();
    fake.result!('とても寂しいです', false);
    fake.status!('notListening');
    fake.status!('done');
    await tester.pump(const Duration(seconds: 3));
    expect(voice.busy, isFalse);
    expect(fake.stops, 0);
    expect(text.text, '  元の文章。\nとても寂しいです');
    expect(voice.feedback, contains('途中の文字'));
    text.text += '。';
    expect(text.text, endsWith('寂しいです。'));
    await voice.toggle();
    expect(fake.starts, 2);
    fake.result!('大丈夫です', true);
    await tester.pump();
    expect(text.text, endsWith('寂しいです。\n大丈夫です'));
  });

  test(
    'listen and stop exceptions unlock input without exposing details',
    () async {
      fake.listenError = StateError('private detail');
      await voice.toggle();
      await flush();
      expect(voice.busy, isFalse);
      expect(voice.error, isNot(contains('private detail')));
      fake.listenError = null;
      await voice.toggle();
      fake.stopError = StateError('private detail');
      await voice.stop();
      expect(voice.busy, isFalse);
      expect(text.text, '  元の文章。\n');
    },
  );

  testWidgets(
    '20-second limit stops; missing final retains partial for review',
    (tester) async {
      await voice.toggle();
      fake.result!('未確定', false);
      await tester.pump(const Duration(seconds: 20));
      expect(fake.stops, 1);
      expect(voice.phase, VoiceInputPhase.stopping);
      await tester.pump(const Duration(seconds: 3));
      expect(voice.busy, isFalse);
      expect(text.text, '  元の文章。\n未確定');
      expect(voice.error, isNull);
      expect(voice.feedback, contains('途中の文字'));
    },
  );

  testWidgets('service never starts: 30-second guard returns to text input', (
    tester,
  ) async {
    fake.emitListening = false;
    await voice.toggle();
    await tester.pump(const Duration(seconds: 30));
    expect(voice.busy, isFalse);
    expect(voice.error, contains('開始できません'));
    expect(fake.cancels, 1);
  });

  test(
    'dispose during permission prompt prevents late microphone start',
    () async {
      fake.initialization = Completer<bool>();
      final pending = voice.toggle();
      voice.dispose();
      fake.initialization!.complete(true);
      await pending;
      await flush();
      expect(fake.starts, 0);
      // Replace disposed controller so shared teardown remains valid.
      voice = VoiceInputController(textController: text, recognition: fake);
    },
  );
}
