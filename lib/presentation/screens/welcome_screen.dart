import 'package:flutter/material.dart';

import 'login_screen.dart';

/// Compatibility entry for existing logout routes. No separate Welcome design
/// exists in the approved Figma file, so all unauthenticated entries show Login.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const LoginScreen();
}
