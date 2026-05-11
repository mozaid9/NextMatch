import 'package:flutter/material.dart';

import 'app_colours.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const display = TextStyle(
    color: AppColours.text,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );

  static const h1 = TextStyle(
    color: AppColours.text,
    fontSize: 28,
    fontWeight: FontWeight.w800,
  );

  static const h2 = TextStyle(
    color: AppColours.text,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static const h3 = TextStyle(
    color: AppColours.text,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(
    color: AppColours.text,
    fontSize: 15,
    height: 1.35,
  );

  static const bodyMuted = TextStyle(
    color: AppColours.mutedText,
    fontSize: 14,
    height: 1.35,
  );

  static const small = TextStyle(
    color: AppColours.mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColours.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColours.accent,
        secondary: AppColours.secondaryGreen,
        surface: AppColours.surface,
        error: AppColours.error,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColours.text,
        displayColor: AppColours.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColours.background,
        foregroundColor: AppColours.text,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColours.surface,
        selectedItemColor: AppColours.accent,
        unselectedItemColor: AppColours.mutedText,
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColours.card,
        labelStyle: const TextStyle(color: AppColours.mutedText),
        hintStyle: const TextStyle(color: AppColours.mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColours.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColours.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColours.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColours.error),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColours.cardAlt,
        contentTextStyle: TextStyle(color: AppColours.text),
      ),
    );
  }
}
