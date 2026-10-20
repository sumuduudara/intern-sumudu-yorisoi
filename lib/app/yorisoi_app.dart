import 'package:flutter/material.dart';

import '../presentation/screens/welcome_screen.dart';
import 'theme/app_theme.dart';

class YorisoiApp extends StatelessWidget {
  const YorisoiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yorisoi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const WelcomeScreen(),
    );
  }
}
