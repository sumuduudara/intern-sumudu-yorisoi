import 'package:flutter/material.dart';

import '../presentation/screens/welcome_screen.dart';
import '../presentation/screens/session_startup_screen.dart';
import 'theme/app_theme.dart';

class YorisoiApp extends StatelessWidget {
  const YorisoiApp({super.key, this.restoreSession});

  /// main() supplies the Firebase action; shell tests can omit it.
  final Future<bool> Function()? restoreSession;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yorisoi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: restoreSession == null
          ? const WelcomeScreen()
          : SessionStartupScreen(restoreSession: restoreSession!),
    );
  }
}
