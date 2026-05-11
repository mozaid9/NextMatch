import 'package:flutter/material.dart';

import '../constants/app_colours.dart';
import '../constants/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColours.accent, size: 36),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTextStyles.bodyMuted,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
