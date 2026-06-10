import 'package:flutter/material.dart';

import '../constants/app_colours.dart';
import '../constants/app_text_styles.dart';
import 'primary_button.dart';
import 'selection_sheet.dart';

/// A consistent bottom-sheet "dialog" used in place of Material AlertDialogs.
/// Matches the look of `_AddFriendSheet` etc. — drag handle, dark surface,
/// title + body text, and one or two primary-styled action buttons.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    this.message,
    required this.child,
  });

  final String title;
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SelectionSheetHandle(),
              Text(title, style: AppTextStyles.h2),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!, style: AppTextStyles.bodyMuted),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a confirm/cancel bottom sheet matching the app's style.
///
/// Returns `true` when confirmed, `false` when dismissed, `null` when the
/// sheet is swiped away without picking anything.
Future<bool?> showAppConfirmSheet({
  required BuildContext context,
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  IconData confirmIcon = Icons.check,
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColours.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (context) => AppSheet(
      title: title,
      message: message,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PrimaryButton(
              label: confirmLabel,
              icon: confirmIcon,
              isSecondary: false,
              onPressed: () => Navigator.of(context).pop(true),
              destructive: isDestructive,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shows a bottom sheet with a single multi-line text input and a
/// confirm/cancel action row. Returns the entered text on confirm
/// (after `validator` passes), or null on cancel/dismiss.
Future<String?> showAppInputSheet({
  required BuildContext context,
  required String title,
  String? message,
  String label = '',
  String? hint,
  String confirmLabel = 'Save',
  IconData confirmIcon = Icons.check,
  bool isDestructive = false,
  int maxLength = 200,
  int maxLines = 3,
  String? initialValue,
  String? Function(String value)? validator,
}) {
  final controller = TextEditingController(text: initialValue ?? '');
  String? errorText;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColours.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => AppSheet(
          title: title,
          message: message,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (label.isNotEmpty) ...[
                Text(
                  label,
                  style: AppTextStyles.small.copyWith(
                    color: AppColours.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              TextField(
                controller: controller,
                maxLines: maxLines,
                minLines: 1,
                maxLength: maxLength,
                autofocus: true,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: hint,
                  errorText: errorText,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: confirmLabel,
                      icon: confirmIcon,
                      destructive: isDestructive,
                      onPressed: () {
                        final value = controller.text.trim();
                        final error = validator?.call(value);
                        if (error != null) {
                          setState(() => errorText = error);
                          return;
                        }
                        Navigator.of(context).pop(value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
