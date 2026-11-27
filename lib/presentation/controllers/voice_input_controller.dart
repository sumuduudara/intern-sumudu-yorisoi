import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../services/voice/speech_to_text_service.dart';

enum VoiceInputPhase { idle, preparing, listening, stopping }

/// Keeps one short utterance separate from the user's existing text.
class VoiceInputController extends ChangeNotifier {
  VoiceInputController({
    required this.textController,
    required this.recognition,
    this.isWeb = kIsWeb,
  });

  final TextEditingController textController;
  final VoiceRecognition recognition;
  final bool isWeb;
  VoiceInputPhase phase = VoiceInputPhase.idle;
  String? error;
  String? feedback;
  String _originalText = '';
  bool _hasPartial = false;
  int _session = 0;
  bool _disposed = false;
  bool _initialized = false;
  bool _ending = false;
  Completer<void>? _finished;
  Future<void>? _starting;
  Timer? _limit;
  Timer? _finalWait;
  Timer? _startWait;

  bool get busy => phase != VoiceInputPhase.idle;
  bool get canTap => !busy || phase == VoiceInputPhase.listening;

  void clearError() {
    if (error == null || _disposed) return;
    error = null;
    notifyListeners();
  }

  String get hint => switch (phase) {
    VoiceInputPhase.preparing => '音声入力を準備しています。',
    VoiceInputPhase.listening => '聞き取り中です。もう一度押すと停止します。',
    VoiceInputPhase.stopping => '音声を確認しています。',
    VoiceInputPhase.idle => feedback ?? '声でも話せるよ · Or use your voice',
  };

  bool _current(int session) => !_disposed && _session == session;

  Future<void> toggle() async {
    if (_disposed) return;
    if (phase == VoiceInputPhase.listening) return stop();
    if (busy) return;
    final session = ++_session;
    _originalText = textController.text;
    _hasPartial = false;
    error = null;
    feedback = null;
    phase = VoiceInputPhase.preparing;
    notifyListeners();
    final starting = _start(session);
    _starting = starting;
    await starting;
    if (identical(_starting, starting)) _starting = null;
  }

  Future<void> _start(int session) async {
    try {
      final ready = await recognition.initialize(
        onStatus: (status) => _status(session, status),
        onError: (code) {
          if (_current(session)) {
            final noSpeech = {
              'no_speech',
              'error_speech_timeout',
              'error_no_match',
              'no_match',
            }.contains(code.toLowerCase().replaceAll('-', '_'));
            unawaited(
              _finish(message: voiceErrorMessage(code), keepPartial: noSpeech),
            );
          }
        },
      );
      _initialized = ready;
      if (!_current(session)) return;
      if (!ready) {
        unawaited(_finish(message: '音声入力を利用できません。文字で入力してください。'));
        return;
      }
      // Do not use browser locales as a Japanese support test.
      final locales = isWeb ? <String>[] : await recognition.locales();
      if (!_current(session)) return;
      final locale = japaneseVoiceLocale(locales, isWeb: isWeb);
      if (locale == null) {
        unawaited(
          _finish(message: voiceErrorMessage('language-not-supported')),
        );
        return;
      }
      await recognition.listen(
        localeId: locale,
        onResult: (words, isFinal) => _result(session, words, isFinal),
      );
      if (!_current(session)) return;
      // A service that never starts must not leave the input locked forever.
      // Permission initialization itself is not timed out by this timer.
      if (phase == VoiceInputPhase.preparing) {
        _startWait = Timer(const Duration(seconds: 30), () {
          if (_current(session)) {
            unawaited(_finish(message: '音声入力を開始できませんでした。文字で入力してください。'));
          }
        });
      }
    } catch (_) {
      if (_current(session)) {
        unawaited(_finish(message: voiceErrorMessage('unknown')));
      }
    }
  }

  void _status(int session, String status) {
    if (!_current(session) || !busy) return;
    if (status == 'listening' && phase == VoiceInputPhase.preparing) {
      _startWait?.cancel();
      phase = VoiceInputPhase.listening;
      _limit = Timer(const Duration(seconds: 20), () => unawaited(stop()));
      notifyListeners();
    } else if (status == 'notListening' && phase != VoiceInputPhase.stopping) {
      if (isWeb) {
        // Web needs stop() to enable the plugin's partial-to-final fallback.
        unawaited(stop());
      } else {
        // Android already stopped recording. A second stop() marks the
        // plugin as user-ended and can suppress the pending native error.
        // Drop the listening color now, but allow the real final/error event.
        _waitForFinalResult(session);
      }
    } else if (status == 'done') {
      if (isWeb) {
        unawaited(_finish(message: voiceErrorMessage('no-speech')));
      } else {
        _waitForFinalResult(session);
      }
    }
  }

  void _result(int session, String words, bool isFinal) {
    if (!_current(session) || !busy) return;
    if (words.trim().isEmpty) {
      if (isFinal) {
        unawaited(
          _finish(
            keepPartial: true,
            message: _hasPartial ? null : voiceErrorMessage('no-speech'),
          ),
        );
      }
      return;
    }
    final separator = _originalText.isEmpty || _originalText.endsWith('\n')
        ? ''
        : '\n';
    final combined = '$_originalText$separator$words';
    textController.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
    _hasPartial = !isFinal;
    if (isFinal) unawaited(_finish(keepResult: true));
  }

  Future<void> stop() async {
    if (_disposed || !busy || phase == VoiceInputPhase.stopping) return;
    final session = _session;
    _waitForFinalResult(session);
    try {
      await recognition.stop();
    } catch (_) {
      if (_current(session)) {
        await _finish(message: voiceErrorMessage('unknown'));
      }
    }
  }

  void _waitForFinalResult(int session) {
    if (!_current(session) || phase == VoiceInputPhase.stopping) return;
    phase = VoiceInputPhase.stopping;
    _limit?.cancel();
    _startWait?.cancel();
    notifyListeners();
    _finalWait = Timer(const Duration(seconds: 3), () {
      if (_current(session)) {
        unawaited(
          _finish(
            keepPartial: true,
            message: _hasPartial ? null : voiceErrorMessage('no-speech'),
          ),
        );
      }
    });
  }

  Future<void> cancel() => _finish();

  Future<void> _finish({
    bool keepResult = false,
    bool keepPartial = false,
    String? message,
  }) async {
    if (_ending) {
      await _finished?.future;
      return;
    }
    if (_disposed || !busy) return;
    _ending = true;
    _finished = Completer<void>();
    final session =
        ++_session; // Ignore final/error events from the old listen.
    _cancelTimers();
    final retainedPartial = keepPartial && _hasPartial;
    if (!keepResult && !retainedPartial) {
      textController.text = _originalText;
    }
    error = message;
    feedback = keepResult
        ? '音声を入力しました。確認・修正できます。'
        : retainedPartial
        ? '聞き取れた途中の文字を残しました。確認・修正してください。'
        : null;
    phase = VoiceInputPhase.stopping;
    notifyListeners();
    // If permissions resolve after cancellation, _start sees the old session
    // and never starts the microphone. Wait before allowing another session.
    await _starting;
    try {
      if (_initialized) await recognition.cancel();
    } catch (_) {
      error ??= '音声入力を終了できませんでした。文字で入力してください。';
    }
    _ending = false;
    if (_current(session)) {
      phase = VoiceInputPhase.idle;
      notifyListeners();
    }
    _finished!.complete();
  }

  void _cancelTimers() {
    _limit?.cancel();
    _finalWait?.cancel();
    _startWait?.cancel();
  }

  @override
  void dispose() {
    // Invalidate callbacks before Home disposes its text controller.
    final needsCancel = busy && !_ending;
    _disposed = true;
    _session++;
    _cancelTimers();
    if (needsCancel) unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    await _starting;
    try {
      if (_initialized) await recognition.cancel();
    } catch (_) {
      // No UI remains. Do not log speech or internal exception details.
    }
  }
}
