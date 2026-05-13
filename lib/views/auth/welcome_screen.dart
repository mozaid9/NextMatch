import 'package:flutter/material.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/primary_button.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Image.asset(
                'assets/images/nextmatchlogo.png',
                height: 200,
                width: 200,
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.productOneLiner,
                style: AppTextStyles.bodyMuted.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: const [
                  _ValueChip(icon: Icons.check_circle, label: 'No chasing'),
                  _ValueChip(icon: Icons.lock, label: 'Paid slots'),
                  _ValueChip(icon: Icons.groups, label: 'Balanced games'),
                ],
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Create account',
                icon: Icons.person_add_alt_1,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Log in',
                icon: Icons.login,
                isSecondary: true,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
