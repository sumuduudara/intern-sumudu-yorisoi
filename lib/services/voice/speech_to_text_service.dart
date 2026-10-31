import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

typedef VoiceResultCallback = void Function(String words, bool isFinal);

/// Small boundary so tests never request a microphone or call a live service.
abstract interface class VoiceRecognition {
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
  });
  Future<List<String>> locales();
  Future<void> listen({
    required String localeId,
    required VoiceResultCallback onResult,
  });
  Future<void> stop();
  Future<void> cancel();
}

/// Web exposes the selected language, not a supported-language catalogue.
String? japaneseVoiceLocale(Iterable<String> locales, {required bool isWeb}) {
  if (isWeb) return 'ja-JP';
  for (final locale in locales) {
    if (locale.toLowerCase().replaceAll('_', '-') == 'ja-jp') return locale;
  }
  return null;
}

String voiceErrorMessage(String code) {
  return switch (code.toLowerCase().replaceAll('-', '_')) {
    'not_allowed' ||
    'service_not_allowed' ||
    'error_permission' ||
    'error_permission_denied' ||
    'error_speech_recognizer_request_not_authorized' ||
    'error_insufficient_permissions' =>
      '音声入力が許可されていません。端末やブラウザの設定を確認するか、文字で入力してください。',
    'no_speech' ||
    'error_speech_timeout' ||
    'error_no_match' ||
    'no_match' => '音声を認識できませんでした。もう一度話すか、文字で入力してください。',
    'language_not_supported' ||
    'error_language_not_supported' ||
    'error_assets_not_installed' ||
    'error_language_unavailable' => 'この環境では日本語の音声入力を利用できません。文字で入力してください。',
    'not supported' ||
    'speech_not_supported' => 'この環境では音声入力を利用できません。文字で入力してください。',
    'audio_capture' ||
    'error_audio' ||
    'error_audio_error' => 'マイクを利用できません。接続や設定を確認するか、文字で入力してください。',
    'error_recognizer_busy' ||
    'error_speech_recognizer_already_active' ||
    'error_busy' => '今は音声入力を開始できません。少し待つか、文字で入力してください。',
    'network' ||
    'error_network' ||
    'error_network_timeout' ||
    'error_server' ||
    'error_server_disconnected' =>
      '音声認識サービスに接続できません。通信を確認して再試行するか、文字で入力してください。',
    _ => '音声入力に失敗しました。もう一度お試しください。文字でも入力できます。',
  };
}

/// One plugin per app. Its initialization callbacks cannot be replaced later,
/// so stable callbacks forward events to the current Home session instead.
class SpeechToTextService implements VoiceRecognition {
  SpeechToTextService({stt.SpeechToText? speech})
    : _speech = speech ?? stt.SpeechToText();

  static final instance = SpeechToTextService();
  final stt.SpeechToText _speech;
  bool _ready = false;
  ValueChanged<String>? _onStatus;
  ValueChanged<String>? _onError;

  @override
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    if (!_ready) {
      _ready = await _speech.initialize(
        onStatus: (status) => _onStatus?.call(status),
        onError: (error) => _onError?.call(error.errorMsg),
        debugLogging: false,
        options: [stt.SpeechToText.androidNoBluetooth],
      );
    }
    return _ready;
  }

  @override
  Future<List<String>> locales() async =>
      (await _speech.locales()).map((locale) => locale.localeId).toList();

  @override
  Future<void> listen({
    required String localeId,
    required VoiceResultCallback onResult,
  }) async {
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 20),
        // Android may deliver no partial words while the user is speaking.
        // The plugin's Dart pause timer measures time since a TEXT result,
        // not microphone silence, so 3 seconds could cut off active speech.
        // Let Android detect silence; keep the 20-second upper bound.
        pauseFor: kIsWeb || defaultTargetPlatform == TargetPlatform.android
            ? null
            : const Duration(seconds: 3),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() async {
    _onStatus = null;
    _onError = null;
    if (_ready) await _speech.cancel();
  }
}
