import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({
    super.key,
    required this.child,
    required this.startupFuture,
  });

  final Widget child;
  final Future<void> startupFuture;

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _ballProgress;
  bool _showApp = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.34, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.18, curve: Curves.easeOut),
    );
    _ballProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.32, 0.72, curve: Curves.easeOutQuart),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        widget.startupFuture
            .then((_) {
              if (mounted) setState(() => _showApp = true);
            })
            .catchError((Object error) {
              if (mounted) setState(() => _startupError = error);
            });
        return;
      }

      Future.wait<void>([_controller.forward(), widget.startupFuture])
          .then((_) {
            if (mounted) setState(() => _showApp = true);
          })
          .catchError((Object error) {
            if (mounted) setState(() => _startupError = error);
          });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return _StartupErrorView(error: _startupError!);
    }

    if (_showApp) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: widget.child,
      );
    }

    return Scaffold(
      backgroundColor: AppColours.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const _PitchBackdrop(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: const _NextMatchKickMark(),
                            ),
                          ),
                          _KickedBall(progress: _ballProgress.value),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: const _Wordmark(),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Text(
                          AppStrings.tagline.toUpperCase(),
                          style: AppTextStyles.small.copyWith(
                            letterSpacing: 3,
                            color: AppColours.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NextMatchKickMark extends StatelessWidget {
  const _NextMatchKickMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      height: 132,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            top: 0,
            child: Text(
              'N',
              style: AppTextStyles.display.copyWith(
                color: AppColours.text,
                fontSize: 118,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w900,
                height: 0.9,
                shadows: [
                  Shadow(
                    color: AppColours.text.withValues(alpha: 0.22),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 42,
            top: 70,
            child: Transform.rotate(
              angle: -0.48,
              child: Container(
                width: 126,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColours.accent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColours.accent.withValues(alpha: 0.42),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 56,
            top: 88,
            child: Transform.rotate(
              angle: -0.48,
              child: Container(
                width: 90,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColours.secondaryGreen,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppTextStyles.h2.copyWith(
          fontSize: 24,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
        children: const [
          TextSpan(
            text: 'NEXT',
            style: TextStyle(color: AppColours.text),
          ),
          TextSpan(
            text: 'MATCH',
            style: TextStyle(color: AppColours.accent),
          ),
        ],
      ),
    );
  }
}

class _KickedBall extends StatelessWidget {
  const _KickedBall({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final x = 34 + (240 * progress);
    final y = -28 - (92 * math.sin(progress * math.pi * 0.92));
    final opacity = progress < 0.03
        ? 0.0
        : progress > 0.84
        ? (1 - progress) / 0.16
        : 1.0;
    final trailOpacity = progress > 0.05 && progress < 0.76
        ? (1 - progress).clamp(0.0, 1.0)
        : 0.0;

    return Transform.translate(
      offset: Offset(x, y),
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              right: 24,
              child: Opacity(
                opacity: trailOpacity,
                child: Transform.rotate(
                  angle: -0.38,
                  child: Container(
                    width: 44 + (36 * progress),
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColours.accent.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
            Transform.rotate(
              angle: progress * math.pi * 7,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColours.text,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColours.background, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColours.accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 25,
                  color: AppColours.background,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PitchBackdrop extends StatelessWidget {
  const _PitchBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PitchBackdropPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _PitchBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColours.line.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final accentPaint = Paint()
      ..color = AppColours.accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      math.min(size.width, size.height) * 0.18,
      accentPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.26,
        size.width * 0.84,
        size.height * 0.48,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColours.error,
                  size: 34,
                ),
                const SizedBox(height: 14),
                Text('Could not start NextMatch', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: AppTextStyles.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
