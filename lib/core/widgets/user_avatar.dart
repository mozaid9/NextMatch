import 'package:flutter/material.dart';

import '../constants/app_colours.dart';
import '../constants/app_text_styles.dart';

/// Renders a circular avatar that shows the user's profile photo when
/// available, falling back to the first letter of their name on a tinted
/// background. Designed to be a drop-in replacement for the various
/// `CircleAvatar` usages scattered around the app.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.fullName,
    this.photoUrl,
    this.radius = 22,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String fullName;
  final String? photoUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  /// Optional outer ring (useful for the profile header where the avatar
  /// overlaps the banner).
  final Color? borderColor;

  String get _initial =>
      fullName.trim().isEmpty ? '?' : fullName.trim()[0].toUpperCase();

  bool get _hasPhoto => photoUrl != null && photoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColours.cardAlt;
    final fg = foregroundColor ?? AppColours.accent;

    final inner = CircleAvatar(
      radius: borderColor != null ? radius - 3 : radius,
      backgroundColor: bg,
      foregroundImage: _hasPhoto ? NetworkImage(photoUrl!) : null,
      child: _hasPhoto
          ? null
          : Text(
              _initial,
              style: _initialStyle(fg),
            ),
    );

    if (borderColor == null) return inner;

    return CircleAvatar(
      radius: radius,
      backgroundColor: borderColor,
      child: inner,
    );
  }

  TextStyle _initialStyle(Color colour) {
    // Pick a sensible font size proportional to the radius.
    if (radius >= 36) {
      return AppTextStyles.h1.copyWith(color: colour);
    }
    if (radius >= 24) {
      return AppTextStyles.h3.copyWith(color: colour);
    }
    return AppTextStyles.body.copyWith(
      color: colour,
      fontWeight: FontWeight.w700,
    );
  }
}
