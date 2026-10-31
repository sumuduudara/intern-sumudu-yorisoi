import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app/yorisoi_app.dart';
import 'services/auth/firebase_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authService = FirebaseAuthService();
  // Only a reset-password action URL opens the code-verified reset form.
  // Never log the action code or forward it to another Firebase project.
  final query = Uri.base.queryParameters;
  final resetCode = query['mode'] == 'resetPassword'
      ? query['oobCode'] ?? ''
      : null;
  runApp(
    YorisoiApp(
      restoreSession: authService.restoreSession,
      passwordResetCode: resetCode,
    ),
  );
}
