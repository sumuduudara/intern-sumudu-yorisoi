import 'package:flutter/material.dart';

import 'registration_screen.dart';

/// The original Figma starts at 01 - Sign Up; there is no separate Welcome frame.
/// Keep the existing signed-out route while showing the actual entry design.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const RegistrationScreen();
}
