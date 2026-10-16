import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'emotion_test.dart';
import 'local_firebase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: localFirebaseOptions());
    if (const bool.fromEnvironment('ENABLE_APP_CHECK')) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidDebugProvider(),
        providerApple: const AppleDebugProvider(),
        providerWeb: kIsWeb
            ? ReCaptchaV3Provider(
                const String.fromEnvironment('RECAPTCHA_SITE_KEY'),
              )
            : null,
      );
    }
    runApp(const EmotionTestApp());
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Firebase initialization failed. Check local configuration and README.',
            ),
          ),
        ),
      ),
    );
  }
}

class EmotionTestApp extends StatefulWidget {
  const EmotionTestApp({super.key});
  @override
  State<EmotionTestApp> createState() => _EmotionTestAppState();
}

class _EmotionTestAppState extends State<EmotionTestApp> {
  String result = 'Not tested yet';
  bool loading = false;
  Future<void> runTest() async {
    setState(() {
      loading = true;
      result = 'Testing...';
    });
    try {
      final emotion = await testYorisoiEmotion();
      if (mounted) setState(() => result = emotion);
    } catch (_) {
      if (mounted) {
        setState(() => result = 'Emotion request failed; check backend and App Check.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Yorisoi AI Test')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: loading ? null : runTest,
              child: const Text('Test Emotion'),
            ),
            SelectableText(result),
          ],
        ),
      ),
    ),
  );
}
