import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/screens/home_screen.dart';

/// Development-only live Home verification without creating a test account.
/// Uses real Firebase and Gemini. Normal authentication still starts in main.dart.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MaterialApp(
      title: 'Yorisoi - Live Home Check',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    ),
  );
}
