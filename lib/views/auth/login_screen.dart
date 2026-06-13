import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/social_sign_in_button.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    final email = await showAppInputSheet(
      context: context,
      title: 'Reset your password',
      message: "We'll email you a link to set a new password.",
      label: 'Email',
      hint: 'you@example.com',
      initialValue: _emailController.text.trim(),
      confirmLabel: 'Send reset link',
      confirmIcon: Icons.mail_outline,
      maxLines: 1,
      validator: (value) => Validators.email(value),
    );
    if (email == null || email.isEmpty || !mounted) return;

    final auth = context.read<AuthViewModel>();
    final success = await auth.sendPasswordResetEmail(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Reset link sent to $email. Check your inbox.'
              : auth.errorMessage ?? 'Could not send the reset email.',
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthViewModel>();
    final success = await auth.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back', style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(
                  'Log in to find your next game.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 24),

                // Social sign-in
                SocialSignInButton(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          await context.read<AuthViewModel>().signInWithApple();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  icon: Icons.apple,
                  label: 'Continue with Apple',
                  dark: true,
                ),
                const SizedBox(height: 10),
                SocialSignInButton(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          await context.read<AuthViewModel>().signInWithGoogle();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  icon: null,
                  label: 'Continue with Google',
                  dark: false,
                ),

                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: AppColours.line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('or sign in with email', style: AppTextStyles.small),
                      ),
                      Expanded(child: Divider(color: AppColours.line)),
                    ],
                  ),
                ),

                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: Validators.password,
                  textInputAction: TextInputAction.done,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: auth.isLoading ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    auth.errorMessage!,
                    style: AppTextStyles.bodyMuted.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Log in',
                  icon: Icons.login,
                  isLoading: auth.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTextStyles.bodyMuted,
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: Text(
                        'Sign up',
                        style: AppTextStyles.bodyMuted.copyWith(
                          color: AppColours.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
