import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_palette.dart';
import '../../core/constants/app_text_styles.dart';
import '../../viewmodels/settings_viewmodel.dart';

/// App settings: appearance (accent colour) and accessibility (text size,
/// high contrast, reduce motion). The account section is added in a later
/// phase.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader('Appearance'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Accent colour', style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  'Used for buttons, links and highlights across the app.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final option in kAccentOptions)
                      _Swatch(
                        option: option,
                        selected: settings.accent == option.colour,
                        onTap: () => settings.setAccent(option.colour),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader('Accessibility'),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Text size', style: AppTextStyles.h3),
                    ),
                    Text(
                      '${(settings.textScale * 100).round()}%',
                      style: AppTextStyles.small.copyWith(
                        color: AppColours.accent,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.textScale,
                  min: SettingsViewModel.minTextScale,
                  max: SettingsViewModel.maxTextScale,
                  divisions: 11,
                  label: '${(settings.textScale * 100).round()}%',
                  onChanged: settings.setTextScale,
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColours.cardAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Preview: the quick brown fox jumps over the lazy dog.',
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.highContrast,
                  onChanged: settings.setHighContrast,
                  title: const Text('High contrast'),
                  subtitle: Text(
                    'Brighter text and borders for easier reading.',
                    style: AppTextStyles.bodyMuted,
                  ),
                ),
                Divider(height: 1, color: AppColours.line),
                SwitchListTile(
                  value: settings.reduceMotion,
                  onChanged: settings.setReduceMotion,
                  title: const Text('Reduce motion'),
                  subtitle: Text(
                    'Minimise animations and transitions.',
                    style: AppTextStyles.bodyMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.small.copyWith(
          color: AppColours.mutedText,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.line),
      ),
      child: child,
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: option.colour,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColours.text : Colors.transparent,
                width: 3,
              ),
            ),
            child: selected
                ? Icon(Icons.check, color: AppColours.background, size: 22)
                : null,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 56,
            child: Text(
              option.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.small.copyWith(
                color: selected ? AppColours.text : AppColours.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
