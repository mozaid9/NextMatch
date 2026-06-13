import 'package:flutter/material.dart';

import 'app_colours.dart';

/// A selectable accent colour shown in Settings → Appearance.
class AccentOption {
  const AccentOption(this.label, this.colour);

  final String label;
  final Color colour;
}

/// The accent colours users can choose from. The first is the original brand
/// green ([AppColours.defaultAccent]).
const List<AccentOption> kAccentOptions = [
  AccentOption('Pitch Green', AppColours.defaultAccent),
  AccentOption('Electric Blue', Color(0xFF2D9CFF)),
  AccentOption('Teal', Color(0xFF1FC8C8)),
  AccentOption('Violet', Color(0xFF8B7BFF)),
  AccentOption('Magenta', Color(0xFFE5468A)),
  AccentOption('Crimson', Color(0xFFFF5A5A)),
  AccentOption('Sunset', Color(0xFFFF8A3D)),
  AccentOption('Gold', Color(0xFFFFC107)),
];
