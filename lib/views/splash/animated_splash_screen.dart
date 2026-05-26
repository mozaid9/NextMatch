import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colours.dart';
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
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _strikeProgress;
  late final Animation<double> _ballProgress;

  bool _animationDone = false;
  bool _startupDone = false;
  bool _showApp = false;
  bool _showLoadingHint = false;
  Object? _startupError;
  Timer? _loadingHintTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1950),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.16, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.3, curve: Curves.easeOutCubic),
      ),
    );
    _strikeProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.58, curve: Curves.easeOutCubic),
    );
    _ballProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.56, 0.9, curve: Curves.easeOutQuart),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (MediaQuery.disableAnimationsOf(context)) {
        _finishReducedMotionStartup();
        return;
      }

      _controller.forward().then((_) {
        if (!mounted) return;
        setState(() => _animationDone = true);
        _tryShowApp();
      });

      widget.startupFuture
          .then((_) {
            if (!mounted) return;
            setState(() => _startupDone = true);
            _tryShowApp();
          })
          .catchError((Object error) {
            if (mounted) setState(() => _startupError = error);
          });

      _loadingHintTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted && !_showApp && _animationDone) {
          setState(() => _showLoadingHint = true);
        }
      });
    });
  }

  Future<void> _finishReducedMotionStartup() async {
    try {
      await widget.startupFuture;
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) setState(() => _showApp = true);
    } catch (error) {
      if (mounted) setState(() => _startupError = error);
    }
  }

  void _tryShowApp() {
    if (_animationDone && _startupDone && mounted) {
      _loadingHintTimer?.cancel();
      setState(() => _showApp = true);
    }
  }

  @override
  void dispose() {
    _loadingHintTimer?.cancel();
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value + _kickPulse(),
                          child: _LayeredLogo(
                            strikeProgress: _strikeProgress.value,
                            ballProgress: _ballProgress.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AnimatedOpacity(
                        opacity: _showLoadingHint ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          'Loading your next game...',
                          style: AppTextStyles.small.copyWith(
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

  double _kickPulse() {
    final progress = _ballProgress.value;
    if (progress < 0.05 || progress > 0.42) return 0;
    return math.sin(progress / 0.42 * math.pi) * 0.025;
  }
}

class _LayeredLogo extends StatelessWidget {
  const _LayeredLogo({
    required this.strikeProgress,
    required this.ballProgress,
  });

  final double strikeProgress;
  final double ballProgress;

  @override
  Widget build(BuildContext context) {
    final ballPosition = _ballOffset(ballProgress);
    final ballOpacity = ballProgress > 0.92 ? (1 - ballProgress) / 0.08 : 1.0;

    return SizedBox(
      width: 310,
      height: 260,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Positioned(top: 18, child: _BaseLogo()),
          Positioned.fill(
            child: CustomPaint(
              painter: _StrikePainter(progress: strikeProgress),
            ),
          ),
          Positioned(
            left: ballPosition.dx,
            top: ballPosition.dy,
            child: Opacity(
              opacity: ballOpacity.clamp(0, 1),
              child: _Football(progress: ballProgress),
            ),
          ),
        ],
      ),
    );
  }

  Offset _ballOffset(double progress) {
    const start = Offset(214, 76);
    const end = Offset(282, 28);

    if (progress == 0) return start;

    final x = start.dx + ((end.dx - start.dx) * progress);
    final y =
        start.dy +
        ((end.dy - start.dy) * progress) -
        (44 * math.sin(progress * math.pi));

    return Offset(x, y);
  }
}

class _BaseLogo extends StatelessWidget {
  const _BaseLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
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
                    color: AppColours.text.withValues(alpha: 0.25),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 136,
            child: RichText(
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
            ),
          ),
          Positioned(
            top: 174,
            child: Text(
              'FIND YOUR NEXT GAME.',
              style: AppTextStyles.small.copyWith(
                color: AppColours.mutedText,
                fontSize: 10,
                letterSpacing: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrikePainter extends CustomPainter {
  const _StrikePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = progress.clamp(0.0, 1.0);
    if (eased == 0) return;

    final primaryPath = Path()
      ..moveTo(84, 144)
      ..cubicTo(126, 128, 168, 104, 224, 76);
    final secondaryPath = Path()
      ..moveTo(96, 158)
      ..cubicTo(136, 144, 174, 120, 208, 98);

    _drawProgressPath(
      canvas,
      primaryPath,
      eased,
      Paint()
        ..color = AppColours.accent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 16,
    );
    _drawProgressPath(
      canvas,
      secondaryPath,
      eased,
      Paint()
        ..color = AppColours.secondaryGreen
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7,
    );
  }

  void _drawProgressPath(
    Canvas canvas,
    Path path,
    double progress,
    Paint paint,
  ) {
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrikePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Football extends StatelessWidget {
  const _Football({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: progress * math.pi * 5,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColours.text,
          shape: BoxShape.circle,
          border: Border.all(color: AppColours.background, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColours.accent.withValues(alpha: 0.42),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.sports_soccer,
          size: 28,
          color: AppColours.background,
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
