import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../viewmodels/auth_viewmodel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthViewModel>();
    final success = await auth.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (success) Navigator.of(context).popUntil((route) => route.isFirst);
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
                Text('Create account', style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(
                  'Secure your place before kick-off.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 28),
                CustomTextField(
                  controller: _nameController,
                  label: 'Full name',
                  icon: Icons.badge_outlined,
                  validator: (value) =>
                      Validators.required(value, label: 'Full name'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
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
                  label: 'Create account',
                  icon: Icons.person_add_alt_1,
                  isLoading: auth.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
