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
        // Hide floating labels project-wide — CustomTextField renders a
        // separate Text label above the field for a cleaner, less Material
        // look.
        floatingLabelBehavior: FloatingLabelBehavior.never,
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
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColours.line),
        ),
        actionTextColor: AppColours.accent,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColours.accent;
          return AppColours.mutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColours.accent.withValues(alpha: 0.3);
          }
          return AppColours.cardAlt;
        }),
        trackOutlineColor: WidgetStateProperty.all(AppColours.line),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColours.accent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColours.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        showDragHandle: false,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColours.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColours.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: AppColours.line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColours.line,
        space: 1,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColours.text),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColours.accent,
        selectionColor: AppColours.accent.withValues(alpha: 0.3),
        selectionHandleColor: AppColours.accent,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColours.text,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: const BorderSide(color: AppColours.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColours.accent,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColours.text,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColours.accent,
        unselectedLabelColor: AppColours.mutedText,
        indicatorColor: AppColours.accent,
        dividerColor: AppColours.line,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColours.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColours.background),
        side: const BorderSide(color: AppColours.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColours.accent;
          return AppColours.mutedText;
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColours.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColours.line),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColours.mutedText,
        textColor: AppColours.text,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColours.cardAlt,
        side: const BorderSide(color: AppColours.line),
        labelStyle: GoogleFonts.inter(
          color: AppColours.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
