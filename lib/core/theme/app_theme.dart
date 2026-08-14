import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const black = Color(0xFF09090B);
  static const panel = Color(0xF012121A);
  static const blue = Color(0xFF00F0FF);
  static const blueGlow = Color(0x2600F0FF);
  static const muted = Color(0xFF8993A5);
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
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: Colors.white, displayColor: Colors.white),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.orbitron(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 20,
        letterSpacing: 2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xF012121A),
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.blue.withValues(alpha: .28)),
      ),
    ),
  );
}
