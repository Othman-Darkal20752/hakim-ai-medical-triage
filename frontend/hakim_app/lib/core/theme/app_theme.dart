import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand colors from Figma Version 3.
  static const Color primary = Color(0xFF087E73);
  static const Color primaryDark = Color(0xFF063D37);
  static const Color primaryForeground = Colors.white;

  static const Color secondary = Color(0xFFE4F3F0);
  static const Color secondaryForeground = Color(0xFF07594F);

  static const Color background = Color(0xFFF5FAF9);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFEFF5F4);
  static const Color accent = Color(0xFFCCECE5);

  static const Color textDark = Color(0xFF163330);
  static const Color textMedium = Color(0xFF3D6860);
  static const Color textLight = Color(0xFF6A807C);

  static const Color border = Color(0xFFDBE9E6);
  static const Color inputBackground = Colors.white;

  static const Color destructive = Color(0xFFC7383D);

  // Medical urgency colors.
  static const Color safeBackground = Color(0xFFE4F5ED);
  static const Color safeForeground = Color(0xFF24734E);

  static const Color soonBackground = Color(0xFFFFF3DC);
  static const Color soonForeground = Color(0xFFA2640B);

  static const Color urgentBackground = Color(0xFFFFF0E7);
  static const Color urgentForeground = Color(0xFFB95719);

  static const Color emergencyBackground = Color(0xFFFCE8EA);
  static const Color emergencyForeground = Color(0xFFB6353A);

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;

  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme.light(
      primary: primary,
      onPrimary: primaryForeground,
      secondary: secondary,
      onSecondary: secondaryForeground,
      surface: surface,
      onSurface: textDark,
      error: destructive,
      onError: Colors.white,
      outline: border,
    );

    final baseTextTheme = ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Arial',

      textTheme: baseTextTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 28,
          height: 1.35,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          height: 1.35,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        headlineSmall: const TextStyle(
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: textDark,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: textMedium,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: textLight,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),

      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: background,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: primary,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          color: textLight,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: textMedium,
          fontSize: 14,
        ),
        prefixIconColor: textLight,
        suffixIconColor: textLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(
            color: destructive,
            width: 1.5,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: border),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          height: 1.35,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: textMedium,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDark,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: secondary,
        circularTrackColor: secondary,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
    );
  }
}