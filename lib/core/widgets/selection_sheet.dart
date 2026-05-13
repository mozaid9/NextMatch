import 'package:flutter/material.dart';

import '../constants/app_colours.dart';
import '../constants/app_text_styles.dart';

class SelectionSheetField extends StatelessWidget {
  const SelectionSheetField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColours.line),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColours.accent, size: 18),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.small),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColours.accent),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final selected = await showSelectionSheet(
      context: context,
      title: label,
      selectedValue: value,
      options: options,
    );

    if (selected != null) onChanged(selected);
  }
}

class SelectionPill extends StatelessWidget {
  const SelectionPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColours.accent.withValues(alpha: 0.14)
              : AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColours.accent : AppColours.line,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.small.copyWith(
            color: selected ? AppColours.accent : AppColours.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class SelectionSheetHandle extends StatelessWidget {
  const SelectionSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColours.line,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

Future<String?> showSelectionSheet({
  required BuildContext context,
  required String title,
  required String selectedValue,
  required List<String> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColours.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (_) => _SelectionSheet(
      title: title,
      selectedValue: selectedValue,
      options: options,
    ),
  );
}

class _SelectionSheet extends StatelessWidget {
  const _SelectionSheet({
    required this.title,
    required this.selectedValue,
    required this.options,
  });

  final String title;
  final String selectedValue;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SelectionSheetHandle(),
            Text(title, style: AppTextStyles.h2),
            const SizedBox(height: 14),
            ...options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SelectionOptionRow(
                  label: option,
                  selected: option == selectedValue,
                  onTap: () => Navigator.of(context).pop(option),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionOptionRow extends StatelessWidget {
  const _SelectionOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColours.accent.withValues(alpha: 0.12)
              : AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColours.accent : AppColours.line,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColours.accent : AppColours.mutedText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
