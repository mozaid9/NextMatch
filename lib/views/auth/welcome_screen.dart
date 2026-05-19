import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/social_sign_in_button.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Image.asset(
                        'assets/images/nextmatchlogo.png',
                        height: 160,
                        width: 160,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.productOneLiner,
                        style: AppTextStyles.bodyMuted.copyWith(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: const [
                          _ValueChip(
                            icon: Icons.check_circle,
                            label: 'No chasing',
                          ),
                          _ValueChip(icon: Icons.lock, label: 'Paid slots'),
                          _ValueChip(
                            icon: Icons.groups,
                            label: 'Balanced games',
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Social sign-in
                      SocialSignInButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => _socialSignIn(context, google: false),
                        icon: Icons.apple,
                        label: 'Continue with Apple',
                        dark: true,
                      ),
                      const SizedBox(height: 10),
                      SocialSignInButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => _socialSignIn(context, google: true),
                        icon: null,
                        label: 'Continue with Google',
                        dark: false,
                      ),

                      // Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Divider(color: AppColours.line),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text('or', style: AppTextStyles.small),
                            ),
                            const Expanded(
                              child: Divider(color: AppColours.line),
                            ),
                          ],
                        ),
                      ),

                      // Email options
                      PrimaryButton(
                        label: 'Create account',
                        icon: Icons.person_add_alt_1,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      PrimaryButton(
                        label: 'Log in with email',
                        icon: Icons.email_outlined,
                        isSecondary: true,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                      ),

                      if (auth.errorMessage != null &&
                          auth.errorMessage!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          auth.errorMessage!,
                          style: AppTextStyles.small.copyWith(
                            color: AppColours.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _socialSignIn(BuildContext context, {required bool google}) async {
    final auth = context.read<AuthViewModel>();
    if (google) {
      await auth.signInWithGoogle();
    } else {
      await auth.signInWithApple();
    }
    // AuthGate handles navigation automatically via authStateChanges stream.
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColours.accent),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.small),
        ],
      ),
    );
  }
}
