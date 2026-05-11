import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/utils/date_time_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../models/match_participant.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../payment/mock_payment_screen.dart';

class MatchDetailScreen extends StatelessWidget {
  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.currentUser,
  });

  final String matchId;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Match details')),
      body: StreamBuilder<FootballMatch?>(
        stream: matchViewModel.matchStream(matchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColours.accent),
            );
          }

          final match = snapshot.data;
          if (match == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Match not found',
                message: 'This game may have been removed by the organiser.',
              ),
            );
          }

          return StreamBuilder<List<MatchParticipant>>(
            stream: matchViewModel.participantsStream(match.id),
            builder: (context, participantSnapshot) {
              final participants = participantSnapshot.data ?? [];
              final isParticipant = participants.any(
                (participant) => participant.userId == currentUser.uid,
              );

              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _Header(match: match),
                          const SizedBox(height: 18),
                          _InfoGrid(match: match),
                          const SizedBox(height: 18),
                          _Section(
                            title: 'Description',
                            child: Text(
                              match.description.isEmpty
                                  ? 'No description added yet.'
                                  : match.description,
                              style: AppTextStyles.bodyMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Needed positions',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: match.neededPositions.entries
                                  .map(
                                    (entry) => _PositionNeed(
                                      label: entry.key,
                                      count: entry.value,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Rules / notes',
                            child: Text(
                              match.cancellationPolicy.isEmpty
                                  ? 'Respect the organiser, arrive on time and bring suitable footwear.'
                                  : match.cancellationPolicy,
                              style: AppTextStyles.bodyMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Section(
                            title: 'Joined players',
                            child: participants.isEmpty
                                ? const Text(
                                    'No confirmed players yet.',
                                    style: AppTextStyles.bodyMuted,
                                  )
                                : Column(
                                    children: participants
                                        .map(
                                          (participant) => _PlayerTile(
                                            participant: participant,
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                          const SizedBox(height: 96),
                        ],
                      ),
                    ),
                    _BottomJoinBar(
                      match: match,
                      isParticipant: isParticipant,
                      onJoin: () => _choosePosition(context, match),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _choosePosition(
    BuildContext context,
    FootballMatch match,
  ) async {
    String selectedPosition = currentUser.preferredPosition;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose your position', style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      'This helps the organiser balance the teams.',
                      style: AppTextStyles.bodyMuted,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPosition,
                      dropdownColor: AppColours.card,
                      decoration: const InputDecoration(
                        labelText: 'Match position',
                      ),
                      items: AppStrings.positions
                          .map(
                            (position) => DropdownMenuItem<String>(
                              value: position,
                              child: Text(position),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => selectedPosition = value);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Continue to payment',
                      icon: Icons.lock,
                      onPressed: () =>
                          Navigator.of(context).pop(selectedPosition),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !context.mounted) return;

    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MockPaymentScreen(
          match: match,
          currentUser: currentUser,
          position: result,
        ),
      ),
    );

    if (!context.mounted || success != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You're in. Payment confirmed.")),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.match});

  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColours.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  color: AppColours.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.title, style: AppTextStyles.h2),
                    const SizedBox(height: 4),
                    Text(match.locationName, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (match.joinedPlayerCount / match.totalPlayersNeeded).clamp(
                0,
                1,
              ),
              backgroundColor: AppColours.line,
              color: match.isFull ? AppColours.error : AppColours.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${match.spacesLabel} spaces filled - ${match.displayStatus}',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.match});

  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoItem(
        icon: Icons.event,
        label: 'Date and time',
        value: DateTimeHelpers.formatMatchDateTime(match.startDateTime),
      ),
      _InfoItem(
        icon: Icons.schedule,
        label: 'Duration',
        value: DateTimeHelpers.formatDuration(match.durationMinutes),
      ),
      _InfoItem(icon: Icons.groups_2, label: 'Format', value: match.format),
      _InfoItem(
        icon: Icons.payments_outlined,
        label: 'Price',
        value: CurrencyHelpers.formatGBP(match.pricePerPlayer),
      ),
      _InfoItem(icon: Icons.bolt, label: 'Skill', value: match.skillLevel),
      _InfoItem(icon: Icons.grass, label: 'Pitch', value: match.pitchType),
      _InfoItem(
        icon: Icons.person,
        label: 'Organiser',
        value: match.organiserName,
      ),
      _InfoItem(icon: Icons.place, label: 'Address', value: match.address),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 92,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColours.accent, size: 18),
          const Spacer(),
          Text(label, style: AppTextStyles.small),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PositionNeed extends StatelessWidget {
  const _PositionNeed({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColours.cardAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $count', style: AppTextStyles.small),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.participant});

  final MatchParticipant participant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColours.cardAlt,
            child: Text(
              participant.fullName.isEmpty
                  ? '?'
                  : participant.fullName[0].toUpperCase(),
              style: const TextStyle(color: AppColours.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(participant.fullName, style: AppTextStyles.body),
                Text(
                  '${participant.position} - ${participant.skillLevel}',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: AppColours.accent, size: 18),
        ],
      ),
    );
  }
}

class _BottomJoinBar extends StatelessWidget {
  const _BottomJoinBar({
    required this.match,
    required this.isParticipant,
    required this.onJoin,
  });

  final FootballMatch match;
  final bool isParticipant;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final label = isParticipant
        ? "You're in"
        : match.isFull
        ? 'Match Full'
        : 'Join Match';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppColours.surface,
        border: Border(top: BorderSide(color: AppColours.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyHelpers.formatGBP(match.pricePerPlayer),
                    style: AppTextStyles.h3,
                  ),
                  Text(
                    'Payment required to secure spot',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 160,
              child: PrimaryButton(
                label: label,
                icon: isParticipant ? Icons.check : Icons.lock,
                onPressed: isParticipant || match.isFull ? null : onJoin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
