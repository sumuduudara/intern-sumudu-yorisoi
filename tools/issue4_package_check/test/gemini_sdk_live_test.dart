// Live cloud test. Only native Firebase Core bootstrap is replaced because
// flutter test has no native Firebase host. HTTP and model output are real.
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi_package_check/local_firebase.dart';
import 'package:yorisoi_package_check/emotion_test.dart';

class LocalCoreHost extends MockFirebaseApp {
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
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(LocalCoreHost());
  // Use the real TLS/network client, rather than Flutter widget test's fake HTTP.
  HttpOverrides.global = null;
  test(
    'real Firebase AI Dart SDK classifies Japanese sentence as lonely',
    () async {
      await Firebase.initializeApp(options: localFirebaseOptions());
      final result = await testYorisoiEmotion();
      expect(result, 'lonely');
      // ignore: avoid_print
      print('LIVE_FIREBASE_AI_SDK emotion=$result');
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_GEMINI'),
  );
}
