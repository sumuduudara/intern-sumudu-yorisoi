import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yorisoi/services/voice/speech_to_text_service.dart';

class FakeVoiceRecognition implements VoiceRecognition {
  bool ready = true;
  bool emitListening = true;
  List<String> installedLocales = ['en_US', 'ja_JP'];
  Completer<bool>? initialization;
  Object? listenError;
  Object? stopError;
  Object? cancelError;
  int starts = 0;
  int stops = 0;
  int cancels = 0;
  int localeQueries = 0;
  String? selectedLocale;
  ValueChanged<String>? status;
  ValueChanged<String>? error;
  VoiceResultCallback? result;

  @override
  Future<bool> initialize({
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
  }) async {
    status = onStatus;
    error = onError;
    return initialization == null ? ready : await initialization!.future;
  }

  @override
  Future<List<String>> locales() async {
    localeQueries++;
    return installedLocales;
  }

  @override
  Future<void> listen({
    required String localeId,
    required VoiceResultCallback onResult,
  }) async {
    starts++;
    selectedLocale = localeId;
    result = onResult;
    if (listenError != null) throw listenError!;
    if (emitListening) status?.call('listening');
  }

  @override
  Future<void> stop() async {
    stops++;
    if (stopError != null) throw stopError!;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (cancelError != null) throw cancelError!;
  }
}
