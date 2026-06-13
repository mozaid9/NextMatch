import 'package:flutter/material.dart';

/// App palette.
///
/// The dark neutrals and status colours are fixed. The brand accent and the
/// text/line colours are settings-driven: [configure] is called from
/// `SettingsViewModel` and the whole app is rebuilt so every `AppColours.x`
/// read picks up the new value. Because the accent and contrast colours are
/// resolved at read time they are getters, so they cannot be used inside
/// `const` expressions — call sites that did were de-`const`-ed.
class AppColours {
  const AppColours._();

  // Fixed dark neutrals.
  static const background = Color(0xFF071014);
  static const surface = Color(0xFF0B171D);
  static const card = Color(0xFF101C22);
  static const cardAlt = Color(0xFF15242B);

  // Fixed status colours (kept semantic, independent of the brand accent).
  static const warning = Color(0xFFFFB020);
  static const error = Color(0xFFFF4D4F);
  static const success = Color(0xFF21D07A);

  /// The original brand green, also the default accent.
  static const defaultAccent = Color(0xFF21D07A);

  static Color _accent = defaultAccent;
  static Color _secondaryGreen = const Color(0xFF16A060);
  static bool _highContrast = false;

  /// Brand accent (buttons, links, highlights, active states).
  static Color get accent => _accent;

  /// A darker shade of the accent, used for gradients and pressed states.
  static Color get secondaryGreen => _secondaryGreen;

  /// Primary text colour. Brighter in high-contrast mode.
  static Color get text =>
      _highContrast ? const Color(0xFFFFFFFF) : const Color(0xFFF5F7FA);

  /// Secondary/muted text. Brighter in high-contrast mode.
  static Color get mutedText =>
      _highContrast ? const Color(0xFFD4DCE1) : const Color(0xFFA8B3BA);

  /// Hairline/border colour. Stronger in high-contrast mode.
  static Color get line =>
      _highContrast ? const Color(0xFF4A5C66) : const Color(0xFF22313A);

  /// Apply the user's appearance settings. Rebuild the app afterwards so the
  /// new values are read across the widget tree.
  static void configure({required Color accent, required bool highContrast}) {
    _accent = accent;
    _secondaryGreen = _darken(accent, 0.12);
    _highContrast = highContrast;
  }

  static Color _darken(Color colour, double amount) {
    final hsl = HSLColor.fromColor(colour);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
