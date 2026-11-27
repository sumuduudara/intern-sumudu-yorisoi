// Opt-in only: actual SDK/network/model; only native Firebase bootstrap is fake.
// Uses the existing ignored local Firebase options, never a committed key.
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/firebase_options.dart';
import 'package:yorisoi/services/emotion/emotion_analysis_service.dart';
import 'package:yorisoi/services/emotion/firebase_emotion_model.dart';

class _LocalCoreHost extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async => CoreInitializeResponse(
    name: appName,
    options: initializeAppRequest,
    pluginConstants: {},
  );
}

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_EMOTION');
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousHttpOverrides = HttpOverrides.current;

  setUpAll(() async {
    if (!live) return;
    TestFirebaseCoreHostApi.setUp(_LocalCoreHost());
    HttpOverrides.global = null;
    try {
      await Firebase.initializeApp(
        // This repository currently has Web options only. Host tests are not
        // Android builds; reuse the existing options without changing them.
        options: DefaultFirebaseOptions.web,
      );
    } catch (_) {
      throw const EmotionAnalysisException(EmotionAnalysisError.configuration);
    }
  });
  tearDownAll(() => HttpOverrides.global = previousHttpOverrides);

  const examples = {
    '今日はひとりで寂しいです': EmotionCategory.lonely,
    '明日のことが心配です': EmotionCategory.anxious,
    '今日はとても楽しいです': EmotionCategory.happy,
  };
  for (final entry in examples.entries) {
    test('LIVE Japanese classification: ${entry.value.englishKey}', () async {
      final service = EmotionAnalysisService(model: FirebaseEmotionModel());
      final result = await service.analyze(entry.key);
      expect(result.main, entry.value);
      // Only validated categories are printed. Never print raw SDK responses.
      // ignore: avoid_print
      print(
        'LIVE_EMOTION main=${result.main.japanese} secondary=${result.secondary?.japanese}',
      );
    }, skip: !live);
  }
}
