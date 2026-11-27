import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/services/emotion/emotion_runtime_diagnostics.dart';

void main() {
  test(
    'logging requires explicit diagnostics flag and emits only safe fields',
    () {
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      try {
        reportEmotionFailure(
          ServerException(
            'Firebase App Check token is invalid. '
            'SYNTHETIC_API_KEY SYNTHETIC_APP_CHECK_TOKEN '
            'Authorization: SYNTHETIC_AUTH test@example.invalid '
            '今日はひとりで寂しいです',
          ),
        );
        const enabled = bool.fromEnvironment('YORISOI_AI_DIAGNOSTICS');
        if (kDebugMode && enabled) {
          expect(lines, hasLength(1));
          expect(lines.single, startsWith('YORISOI_AI_FAILURE '));
          expect(lines.single, contains('app_check_token_invalid'));
          expect(lines.single, isNot(contains('SYNTHETIC')));
          expect(lines.single, isNot(contains('Authorization')));
          expect(lines.single, isNot(contains('@')));
          expect(lines.single, isNot(contains('寂しい')));
        } else {
          expect(lines, isEmpty);
        }
      } finally {
        debugPrint = previous;
      }
    },
  );

  test('extracts only HTTP status from App Check exchange rejection', () {
    for (final status in [400, 403, 429, 500]) {
      final result = emotionFailureDiagnostic(
        FirebaseException(
          plugin: 'app-check',
          code: 'fetch-status-error',
          message:
              'Fetch server returned an HTTP error status. HTTP status: $status. private credential',
        ),
      );
      expect(result['http_status'], '$status');
      expect(result.toString(), isNot(contains('private')));
    }
    expect(
      emotionFailureDiagnostic(
        FirebaseException(
          plugin: 'app-check',
          code: 'fetch-status-error',
          message: 'private credential',
        ),
      ),
      isNot(contains('http_status')),
    );
  });
  test(
    'identifies exact known App Check rejection without copying SDK text',
    () {
      final result = emotionFailureDiagnostic(
        ServerException(
          'Firebase App Check token is invalid. private credential',
        ),
      );
      expect(result['exception'], 'ServerException');
      expect(result['reason'], 'app_check_token_invalid');
      expect(result.toString(), isNot(contains('private')));
    },
  );

  test('identifies App Check exchange errors without exposing message', () {
    expect(
      emotionFailureDiagnostic(
        FirebaseException(
          plugin: 'firebase_app_check',
          code: 'fetch-status-error',
          message: 'private credential',
        ),
      ),
      {
        'exception': 'FirebaseException',
        'plugin': 'firebase_app_check',
        'code': 'fetch-status-error',
      },
    );
  });

  test('unknown codes, SDK bodies and exception strings never escape', () {
    final errors = [
      FirebaseException(
        plugin: 'private plugin',
        code: 'private code',
        message: 'private credential',
      ),
      ServerException('private credential'),
      const FormatException('private credential'),
      StateError('private credential'),
      FirebaseAISdkException('private credential'),
    ];
    for (final error in errors) {
      expect(
        emotionFailureDiagnostic(error).toString(),
        isNot(contains('private')),
      );
    }
  });

  test(
    'reports SDK parsing exception type and only allowlisted server status',
    () {
      expect(emotionFailureDiagnostic(FirebaseAISdkException('private body')), {
        'exception': 'FirebaseAISdkException',
      });
      final diagnostic = emotionFailureDiagnostic(
        ServerException('INVALID_ARGUMENT private body'),
      );
      expect(diagnostic['status'], 'invalid_argument');
      expect(diagnostic.toString(), isNot(contains('private')));
      expect(
        emotionFailureDiagnostic(ServerException('private body'))['status'],
        'not_exposed',
      );
    },
  );
}
