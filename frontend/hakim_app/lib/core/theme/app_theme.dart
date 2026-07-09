import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF0F766E);
  static const Color secondary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMedium = Color(0xFF475569);
  static const Color textLight = Color(0xFF64748B);

  static const Color border = Color(0xFFE2E8F0);
  static const Color inputBackground = Color(0xFFF1F5F9);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Arial',
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: background,
        elevation: 0,
        foregroundColor: textDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}