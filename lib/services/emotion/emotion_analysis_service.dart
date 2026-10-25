import 'dart:async';

import '../../domain/emotions/emotion_analysis_result.dart';

abstract interface class EmotionTextModel {
  Future<String?> classify(String text);
}

enum EmotionAnalysisError {
  emptyInput,
  invalidResponse,
  timeout,
  configuration,
  permissionDenied,
  quotaExceeded,
  blocked,
  apiFailure,
}

/// Only a safe code/message leaves this boundary; raw backend errors stay out
/// of UI, test logs, and exception strings.
class EmotionAnalysisException implements Exception {
  const EmotionAnalysisException(this.code);
  final EmotionAnalysisError code;

  String get japaneseMessage => switch (code) {
    EmotionAnalysisError.emptyInput => '今の気持ちを入力してください。',
    EmotionAnalysisError.invalidResponse => '感情の結果を確認できませんでした。もう一度お試しください。',
    EmotionAnalysisError.timeout => '処理に時間がかかっています。もう一度お試しください。',
    EmotionAnalysisError.configuration => '現在、感情分析を利用できません。入力内容はそのまま保持してください。',
    EmotionAnalysisError.permissionDenied => '感情分析を利用できません。アプリの設定確認が必要です。',
    EmotionAnalysisError.quotaExceeded => '現在、利用が集中しています。しばらくしてからお試しください。',
    EmotionAnalysisError.blocked => 'この文章の感情を確認できませんでした。入力内容を確認してください。',
    EmotionAnalysisError.apiFailure => '感情分析に失敗しました。接続を確認して、もう一度お試しください。',
  };

  @override
  String toString() => 'EmotionAnalysisException(${code.name})';
}

class EmotionAnalysisService {
  EmotionAnalysisService({
    required this.model,
    this.timeout = const Duration(seconds: 30),
  }) {
    if (timeout <= Duration.zero) {
      throw ArgumentError('Emotion analysis timeout must be positive.');
    }
  }

  final EmotionTextModel model;
  final Duration timeout;

  Future<EmotionAnalysisResult> analyze(String input) async {
    final text = input.trim();
    if (text.isEmpty) {
      throw const EmotionAnalysisException(EmotionAnalysisError.emptyInput);
    }
    try {
      final response = await model.classify(text).timeout(timeout);
      return EmotionAnalysisResult.fromJsonString(response);
    } on EmotionAnalysisException {
      rethrow;
    } on TimeoutException {
      throw const EmotionAnalysisException(EmotionAnalysisError.timeout);
    } on FormatException {
      throw const EmotionAnalysisException(
        EmotionAnalysisError.invalidResponse,
      );
    } catch (_) {
      throw const EmotionAnalysisException(EmotionAnalysisError.apiFailure);
    }
  }
}
