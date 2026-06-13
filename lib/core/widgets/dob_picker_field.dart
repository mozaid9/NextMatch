import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../constants/app_colours.dart';
import '../constants/app_text_styles.dart';

/// A tappable date-of-birth field. Opens a date picker and shows the live
/// computed age beside the chosen date (e.g. "07/09/2003 · 22 years"), matching
/// the label-above / filled-input look of [CustomTextField]. For legacy
/// accounts with a stored age but no date of birth, [fallbackAge] is shown as a
/// hint until the player picks a date.
class DobPickerField extends StatelessWidget {
  const DobPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.fallbackAge,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final int? fallbackAge;

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now, // No future births; no minimum-age gate.
      helpText: 'Select your date of birth',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    final hasFallback = (fallbackAge ?? 0) > 0;
    final hint = hasFallback
        ? 'Age $fallbackAge — tap to set date of birth'
        : 'Tap to choose your date of birth';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of birth',
          style: AppTextStyles.small.copyWith(
            color: AppColours.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            isEmpty: v == null,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.cake_outlined, size: 18),
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              isDense: true,
              floatingLabelBehavior: FloatingLabelBehavior.never,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            child: v == null
                ? null
                : Text(
                    '${_format(v)}  ·  ${AppUser.ageFromDate(v)} years',
                    style: AppTextStyles.body,
                  ),
          ),
        ),
      ],
    );
  }
}
