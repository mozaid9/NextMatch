import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colours.dart';

class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.dark,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool dark;

  /// Material icon — pass null to show the Google "G" placeholder instead.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1A1A1A) : AppColours.card;
    final border = dark ? const Color(0xFF333333) : AppColours.line;
    final fg = dark ? Colors.white : AppColours.text;
    final contentWidth = math.min(MediaQuery.sizeOf(context).width - 72, 250.0);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Center(
          child: SizedBox(
            width: contentWidth,
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 28,
                  child: Center(
                    child: _ProviderLogo(icon: icon, colour: fg),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.icon, required this.colour});

  final IconData? icon;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return Icon(icon, size: 28, color: colour);
    }

    // The Google source PNG is 2:1 with the G centred inside it. Cover-cropping
    // to a square removes that transparent side padding without needing a
    // second hand-cropped asset.
    return ClipRect(
      child: SizedBox.square(
        dimension: 24,
        child: Image.asset('assets/images/google_g.png', fit: BoxFit.cover),
      ),
    );
  }
}

/// Renders the recognisable 4-colour Google "G" logo with a CustomPainter.
/// No asset files or extra packages required.
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  // Official Google brand colours
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.20;
    final rect = Rect.fromCircle(
      center: Offset(s / 2, s / 2),
      radius: (s / 2) - stroke / 2,
    );

    final paint = Paint()
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    // Flutter drawArc: 0 rad = 3 o'clock, sweep increases clockwise.
    // We leave a small gap on the right (where the "G" crossbar emerges).
    const gap = math.pi / 14;
    final totalSweep = 2 * math.pi - gap * 2;
    final segment = totalSweep / 4;

    // Going clockwise from just below 3 o'clock:
    // green (bottom-right) → yellow (bottom-left) → red (top-left) → blue (top-right)
    final colours = [_green, _yellow, _red, _blue];
    var start = gap;
    for (final colour in colours) {
      paint.color = colour;
      canvas.drawArc(rect, start, segment, false, paint);
      start += segment;
    }

    // Inner horizontal "crossbar" of the G — blue, from centre to right edge.
    final barFill = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    final barHeight = stroke * 0.95;
    canvas.drawRect(
      Rect.fromLTRB(
        s * 0.50,
        s / 2 - barHeight / 2,
        s - stroke * 0.55,
        s / 2 + barHeight / 2,
      ),
      barFill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
