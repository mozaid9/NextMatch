import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colours.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle get display => GoogleFonts.inter(
    color: AppColours.text,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.05,
  );

  static TextStyle get h1 => GoogleFonts.inter(
    color: AppColours.text,
    fontSize: 28,
    fontWeight: FontWeight.w800,
  );

  static TextStyle get h2 => GoogleFonts.inter(
    color: AppColours.text,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    color: AppColours.text,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get body =>
      GoogleFonts.inter(color: AppColours.text, fontSize: 15, height: 1.35);

  static TextStyle get bodyMuted => GoogleFonts.inter(
    color: AppColours.mutedText,
    fontSize: 14,
    height: 1.35,
  );

  static TextStyle get small => GoogleFonts.inter(
    color: AppColours.mutedText,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    final interTextTheme = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColours.text, displayColor: AppColours.text);

    return base.copyWith(
      scaffoldBackgroundColor: AppColours.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColours.accent,
        secondary: AppColours.secondaryGreen,
        surface: AppColours.surface,
        error: AppColours.error,
      ),
      textTheme: interTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColours.background,
        foregroundColor: AppColours.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: AppColours.text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColours.surface,
        indicatorColor: AppColours.accent.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColours.accent);
          }
          return const IconThemeData(color: AppColours.mutedText);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              color: AppColours.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return GoogleFonts.inter(color: AppColours.mutedText, fontSize: 12);
        }),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColours.card,
        labelStyle: GoogleFonts.inter(color: AppColours.mutedText),
        hintStyle: GoogleFonts.inter(color: AppColours.mutedText),
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColours.cardAlt,
        contentTextStyle: GoogleFonts.inter(color: AppColours.text),
      ),
    );
  }
}
