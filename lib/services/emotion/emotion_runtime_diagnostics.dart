import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// A fixed vocabulary only: never copy SDK messages, headers or user text.
Map<String, String> emotionFailureDiagnostic(Object error) {
  if (error is FirebaseException) {
    const plugins = {
      'firebase_app_check',
      'app-check',
      'firebase_auth',
      'firebase_core',
    };
    const codes = {
      'fetch-status-error',
      'fetch-network-error',
      'fetch-parse-error',
      'recaptcha-error',
      'throttled',
      'permission-denied',
      'unauthenticated',
      'network-request-failed',
      'invalid-user-token',
      'user-token-expired',
      'user-disabled',
      'no-app',
    };
    // Firebase JS preserves the HTTP status in this error's message, not
    // Flutter's code. Extract only a three-digit status, never the message.
    final status =
        (error.plugin == 'app-check' || error.plugin == 'firebase_app_check') &&
            error.code == 'fetch-status-error'
        ? RegExp(r'HTTP status:\s*([1-5][0-9]{2})\b')
              .firstMatch(error.message ?? '')
              ?.group(1)
        : null;
    return {
      'exception': 'FirebaseException',
      'plugin': plugins.contains(error.plugin) ? error.plugin : 'unlisted',
      'code': codes.contains(error.code) ? error.code : 'unlisted',
      'http_status': ?status,
    };
  }
  if (error is FirebaseAIException) {
    final message = error.message.toLowerCase();
    // This SDK exposes message, not a structured server code. Match only
    // known status words rather than printing the message to recover a code.
    const statuses = {
      'permission_denied',
      'unauthenticated',
      'invalid_argument',
      'not_found',
      'resource_exhausted',
      'unavailable',
      'internal',
    };
    return {
      'exception': error is ServerException
          ? 'ServerException'
          : 'FirebaseAIException',
      'reason': message.contains('firebase app check token is invalid')
          ? 'app_check_token_invalid'
          : message.contains('genai config not found')
          ? 'genai_configuration_missing'
          : message.contains('permission_denied') ||
                message.contains('permission denied')
          ? 'permission_denied'
          : 'unlisted',
      'status': statuses.firstWhere(
        (status) => RegExp('\\b$status\\b').hasMatch(message),
        orElse: () => 'not_exposed',
      ),
    };
  }
  return {
    'exception': error is FirebaseAISdkException
        ? 'FirebaseAISdkException'
        : error is FormatException
        ? 'FormatException'
        : error is TypeError
        ? 'TypeError'
        : error is StateError
        ? 'StateError'
        : 'unlisted',
  };
}

void reportEmotionFailure(Object error) {
  if (kDebugMode && const bool.fromEnvironment('YORISOI_AI_DIAGNOSTICS')) {
    debugPrint('YORISOI_AI_FAILURE ${emotionFailureDiagnostic(error)}');
  }
}
