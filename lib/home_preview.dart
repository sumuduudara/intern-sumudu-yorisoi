import 'dart:async';

import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';

/// Home preview and real microphone test without Firebase authentication.
/// Analysis and recommendations remain previews. Production uses main.dart.
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
