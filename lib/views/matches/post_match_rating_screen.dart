import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../models/match_participant.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../../viewmodels/rating_viewmodel.dart';

class PostMatchRatingScreen extends StatefulWidget {
  const PostMatchRatingScreen({
    super.key,
    required this.match,
    required this.currentUser,
  });

  final FootballMatch match;
  final AppUser currentUser;

  @override
  State<PostMatchRatingScreen> createState() => _PostMatchRatingScreenState();
}

class _PostMatchRatingScreenState extends State<PostMatchRatingScreen> {
  final Map<String, double> _ratings = {};

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();
    final ratingViewModel = context.watch<RatingViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Rate players')),
      body: StreamBuilder<List<MatchParticipant>>(
        stream: matchViewModel.participantsStream(widget.match.id),
        builder: (context, snapshot) {
          final participants = snapshot.data ?? [];
          final currentParticipant = participants
              .where(
                (participant) => participant.userId == widget.currentUser.uid,
              )
              .toList();
          final canRate =
              widget.match.isCompleted &&
              currentParticipant.isNotEmpty &&
              currentParticipant.first.attendanceStatus == 'Attended';
          final rateablePlayers = participants
              .where(
                (participant) =>
                    participant.userId != widget.currentUser.uid &&
                    participant.attendanceStatus == 'Attended',
              )
              .toList();

          if (!canRate) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.lock_outline,
                title: 'Ratings unavailable',
                message:
                    'Only attended players can rate other attended players after the match is completed.',
              ),
            );
          }

          if (rateablePlayers.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.group_off_outlined,
                title: 'No players to rate',
                message: 'There are no other attended players to rate yet.',
              ),
            );
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(widget.match.title, style: AppTextStyles.h1),
                const SizedBox(height: 8),
                Text(
                  'Rate each player’s football ability from 1 to 5. Reliability is tracked separately.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 18),
                ...rateablePlayers.map(
                  (participant) => _RatingTile(
                    participant: participant,
                    value: _ratings[participant.userId] ?? 3,
                    onChanged: (value) {
                      setState(() => _ratings[participant.userId] = value);
                    },
                  ),
                ),
                if (ratingViewModel.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    ratingViewModel.errorMessage!,
                    style: AppTextStyles.bodyMuted.copyWith(
                      color: AppColours.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Submit ratings',
                  icon: Icons.star_rate,
                  isLoading: ratingViewModel.isLoading,
                  onPressed: () async {
                    for (final player in rateablePlayers) {
                      _ratings.putIfAbsent(player.userId, () => 3);
                    }
                    final success = await ratingViewModel.submitRatings(
                      matchId: widget.match.id,
                      ratedByUserId: widget.currentUser.uid,
                      ratingsByUserId: _ratings,
                    );
                    if (!context.mounted || !success) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ratings submitted.')),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.participant,
    required this.value,
    required this.onChanged,
  });

  final MatchParticipant participant;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                      '${participant.position} · ${participant.skillLevel}',
                      style: AppTextStyles.small,
                    ),
                  ],
                ),
              ),
              Text(
                '${value.toInt()}/5',
                style: AppTextStyles.h3.copyWith(color: AppColours.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: AppColours.accent,
            inactiveColor: AppColours.line,
            label: _labelFor(value),
            onChanged: onChanged,
          ),
          Text(_labelFor(value), style: AppTextStyles.bodyMuted),
        ],
      ),
    );
  }

  String _labelFor(double value) {
    return switch (value.round()) {
      1 => 'Beginner',
      2 => 'Below average',
      3 => 'Decent',
      4 => 'Good',
      _ => 'Excellent',
    };
  }
}
