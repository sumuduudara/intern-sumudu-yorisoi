import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF487568));
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
    );
  }
}
