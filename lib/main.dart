import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app/yorisoi_app.dart';
import 'services/auth/firebase_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authService = FirebaseAuthService();
  runApp(YorisoiApp(restoreSession: authService.restoreSession));
}
