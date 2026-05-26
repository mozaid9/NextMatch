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

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> {
  bool _showApp = false;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    try {
      // Keep the branded launch screen visible for a beat so startup feels
      // intentional instead of flashing between blank and authenticated states.
      await Future.wait<void>([
        widget.startupFuture,
        Future<void>.delayed(const Duration(milliseconds: 650)),
      ]);
      if (mounted) setState(() => _showApp = true);
    } catch (error) {
      if (mounted) setState(() => _startupError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return _StartupErrorView(error: _startupError!);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _showApp ? widget.child : const _LogoSplashView(),
    );
  }
}

class _LogoSplashView extends StatelessWidget {
  const _LogoSplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/nextmatchlogo.png',
                  width: 220,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 26),
                Text(
                  AppStrings.tagline,
                  style: AppTextStyles.bodyMuted.copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColours.accent,
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
