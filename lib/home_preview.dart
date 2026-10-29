import 'dart:async';

import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';

/// Explicit visual preview entrypoint. Production still starts in main.dart
/// and checks Firebase authentication. This preview does not initialize Firebase.
void main() {
  runApp(
    MaterialApp(
      title: 'Yorisoi — Home UI Preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: HomeScreen(
        displayName: 'Sumudu', // Figma sample name, used only by this preview.
        previewOnly: true,
        // Keep 03-A visible for comparison until "入力に戻る" is pressed.
        analysisPreviewAction: (_) => Completer<void>().future,
      ),
    ),
  );
}
