import 'package:flutter/material.dart';

import '../../models/football_match.dart';
import '../constants/app_colours.dart';
import '../constants/app_text_styles.dart';
import '../utils/currency_helpers.dart';
import '../utils/date_time_helpers.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.onTap,
    this.actionLabel,
    this.onActionPressed,
    this.trailing,
  });

  final FootballMatch match;
  final VoidCallback onTap;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final statusColour = switch (match.displayStatus) {
      'Full' => AppColours.error,
      'Nearly Full' => AppColours.warning,
      'Completed' => AppColours.mutedText,
      'Cancelled' => AppColours.error,
      _ => AppColours.accent,
    };

    return Card(
      color: AppColours.card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColours.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.title,
                          style: AppTextStyles.h3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateTimeHelpers.formatMatchDateTime(
                            match.startDateTime,
                          ),
                          style: AppTextStyles.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusPill(label: match.displayStatus, colour: statusColour),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    _InfoChip(icon: Icons.place, label: match.locationName),
                    const SizedBox(width: 8),
                    _InfoChip(icon: Icons.groups_2, label: match.format),
                    const SizedBox(width: 8),
                    _InfoChip(icon: Icons.bolt, label: match.skillLevel),
                    const SizedBox(width: 8),
                    _InfoChip(icon: Icons.grass, label: match.pitchType),
                    if (match.requiresApprovalForLowReliability) ...[
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.verified_user_outlined,
                        label: 'Min ${match.minimumReliabilityRequired} rel.',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.isOrganiserPays
                          ? 'Free to join · ${CurrencyHelpers.formatGBP(match.pricePerPlayer)} owed'
                          : '${CurrencyHelpers.formatGBP(match.pricePerPlayer)} per player',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${match.spacesLabel} filled',
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: (match.joinedPlayerCount / match.totalPlayersNeeded)
                      .clamp(0, 1),
                  backgroundColor: AppColours.line,
                  color: statusColour,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Organised by ${_capitaliseName(match.organiserName)}',
                      style: AppTextStyles.small,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) trailing!,
                  if (actionLabel != null && onActionPressed != null)
                    TextButton.icon(
                      onPressed: onActionPressed,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: Text(actionLabel!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _capitaliseName(String name) => name
    .split(' ')
    .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
    .join(' ');

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColours.cardAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColours.mutedText),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.small),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.colour});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: AppTextStyles.small.copyWith(color: colour)),
    );
  }
}
