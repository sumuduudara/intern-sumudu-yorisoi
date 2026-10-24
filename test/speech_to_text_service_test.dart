import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:yorisoi/presentation/controllers/voice_input_controller.dart';
import 'package:yorisoi/services/voice/speech_to_text_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late SpeechToTextService service;

  Future<void> event(String method, Object argument) async {
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, argument)),
      null,
    );
  }

  setUp(() {
    calls = [];
    service = SpeechToTextService(speech: stt.SpeechToText.withMethodChannel());
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' || 'listen' => true,
        'locales' => ['ja_JP:日本語'],
        _ => null,
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('successful initialization happens once and routes callbacks to current Home', () async {
    final first = <String>[];
    final second = <String>[];
    expect(
      await service.initialize(onStatus: first.add, onError: first.add),
      isTrue,
    );
    await service.cancel();
    expect(
      await service.initialize(onStatus: second.add, onError: second.add),
      isTrue,
    );
    await event('notifyStatus', 'listening');
    await event(
      'notifyError',
      jsonEncode({'errorMsg': 'network', 'permanent': false}),
    );
    expect(first, isEmpty);
    expect(second, ['listening', 'network']);
    final init = calls.where((call) => call.method == 'initialize').single;
    expect(init.arguments['debugLogging'], false);
    expect(init.arguments['noBluetooth'], true);
    await service.cancel();
  });

  testWidgets(
    'real plugin options and 2-second partial-to-final fallback keep web-like results',
    (tester) async {
      final text = TextEditingController(text: '元の文');
      final voice = VoiceInputController(
        textController: text,
        recognition: service,
        isWeb: true,
      );
      addTearDown(() {
        voice.dispose();
        text.dispose();
      });
      await voice.toggle();
      final listen = calls.singleWhere((call) => call.method == 'listen');
      expect(listen.arguments['localeId'], 'ja-JP');
      expect(listen.arguments['partialResults'], true);
      expect(listen.arguments['listenFor'], 20000);
      expect(listen.arguments['listenMode'], stt.ListenMode.dictation.index);
      await event('notifyStatus', 'listening');
      await event(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': 'とても寂しいです', 'confidence': -1.0},
          ],
          'resultType': 0,
        }),
      );
      await event('notifyStatus', 'notListening');
      await event('notifyStatus', 'done');
      await tester.pump();
      expect(voice.phase, VoiceInputPhase.stopping);
      await tester.pump(const Duration(seconds: 2));
      expect(voice.busy, isFalse);
      expect(text.text, '元の文\nとても寂しいです');
      expect(voice.error, isNull);
      expect(calls.where((call) => call.method == 'cancel'), hasLength(1));
    },
  );
}
