import 'package:flutter/material.dart';

abstract final class AppColors {
  static const black = Color(0xFF05070A);
  static const panel = Color(0xEE0C1118);
  static const blue = Color(0xFF00A8FF);
  static const blueGlow = Color(0x6600A8FF);
  static const muted = Color(0xFF8B98A7);
  static const danger = Color(0xFFFF334F);
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.black,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.blue,
      secondary: AppColors.blue,
      surface: AppColors.panel,
      error: AppColors.danger,
    ),
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
