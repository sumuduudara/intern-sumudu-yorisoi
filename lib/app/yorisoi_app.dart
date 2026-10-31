import 'package:flutter/material.dart';

import '../presentation/screens/welcome_screen.dart';
import '../presentation/screens/session_startup_screen.dart';
import 'theme/app_theme.dart';
import '../presentation/screens/set_new_password_screen.dart';

class YorisoiApp extends StatelessWidget {
  const YorisoiApp({super.key, this.restoreSession, this.passwordResetCode});

  final String? passwordResetCode;

  /// main() supplies the Firebase action; shell tests can omit it.
  final Future<bool> Function()? restoreSession;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yorisoi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      home: passwordResetCode != null
          ? SetNewPasswordScreen(code: passwordResetCode!)
          : restoreSession == null
          ? const WelcomeScreen()
          : SessionStartupScreen(restoreSession: restoreSession!),
    );
  }
}
