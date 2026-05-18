import 'package:flutter/material.dart';

import '../constants/app_colours.dart';
import '../constants/app_text_styles.dart';

/// Field with a static label above and a filled rounded input below — no
/// floating Material label cutting into the border. Looks at home on web,
/// iOS and Android.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.maxLines = 1,
    this.textInputAction,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final int maxLines;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.small.copyWith(
            color: AppColours.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          textInputAction: textInputAction,
          autofocus: autofocus,
          onChanged: onChanged,
          validator: validator,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, size: 18),
            isDense: true,
            // Override theme's floating label so nothing cuts into the border.
            labelText: null,
            floatingLabelBehavior: FloatingLabelBehavior.never,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
