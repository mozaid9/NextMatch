import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/match_card.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../models/match_participant.dart';
import '../../viewmodels/match_viewmodel.dart';
import 'match_detail_screen.dart';

class MyMatchesScreen extends StatelessWidget {
  const MyMatchesScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My matches'),
          bottom: const TabBar(
            indicatorColor: AppColours.accent,
            labelColor: AppColours.accent,
            unselectedLabelColor: AppColours.mutedText,
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
              Tab(text: 'Organised'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _JoinedMatchesList(currentUser: currentUser, showPast: false),
            _JoinedMatchesList(currentUser: currentUser, showPast: true),
            _OrganisedMatchesList(currentUser: currentUser),
          ],
        ),
      ),
    );
  }
}

class _JoinedMatchesList extends StatelessWidget {
  const _JoinedMatchesList({required this.currentUser, required this.showPast});

  final AppUser currentUser;
  final bool showPast;

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: matchViewModel.joinedMatchSummariesStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColours.accent),
          );
        }

        final summaries = (snapshot.data ?? []).where((summary) {
          final date = _summaryDate(summary);
          final isPast = date.isBefore(DateTime.now());
          return showPast ? isPast : !isPast;
        }).toList();

        if (summaries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: EmptyState(
              icon: showPast ? Icons.history : Icons.event_available,
              title: showPast ? 'No past matches yet' : 'No upcoming matches',
              message: showPast
                  ? 'Completed games will appear here.'
                  : 'Join and mock-pay for a match to lock in your place.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: summaries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final summary = summaries[index];
            return FutureBuilder<FootballMatch?>(
              future: matchViewModel.getMatch(summary['matchId'] as String),
              builder: (context, matchSnapshot) {
                final match = matchSnapshot.data;
                if (match == null) {
                  return const SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColours.accent,
                      ),
                    ),
                  );
                }

                return MatchCard(
                  match: match,
                  trailing: _PaymentBadge(
                    label: summary['paymentStatus'] as String? ?? 'Confirmed',
                  ),
                  onTap: () => _openDetail(context, match),
                );
              },
            );
          },
        );
      },
    );
  }

  DateTime _summaryDate(Map<String, dynamic> summary) {
    final value = summary['matchDateTime'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  void _openDetail(BuildContext context, FootballMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MatchDetailScreen(matchId: match.id, currentUser: currentUser),
      ),
    );
  }
}

class _OrganisedMatchesList extends StatelessWidget {
  const _OrganisedMatchesList({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

    return StreamBuilder<List<FootballMatch>>(
      stream: matchViewModel.organisedMatchesStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColours.accent),
          );
        }

        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No organised matches',
              message: 'Create a match to start filling spaces.',
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: matches.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final match = matches[index];
            return _OrganisedMatchCard(match: match, currentUser: currentUser);
          },
        );
      },
    );
  }
}

class _OrganisedMatchCard extends StatelessWidget {
  const _OrganisedMatchCard({required this.match, required this.currentUser});

  final FootballMatch match;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final revenue = match.joinedPlayerCount * match.pricePerPlayer;
    final matchViewModel = context.watch<MatchViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MatchCard(
          match: match,
          trailing: Text(
            '${CurrencyHelpers.formatGBP(revenue)} collected',
            style: AppTextStyles.small.copyWith(color: AppColours.accent),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MatchDetailScreen(
                  matchId: match.id,
                  currentUser: currentUser,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
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
              Text('Player list', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              StreamBuilder<List<MatchParticipant>>(
                stream: matchViewModel.participantsStream(match.id),
                builder: (context, snapshot) {
                  final participants = snapshot.data ?? [];
                  if (participants.isEmpty) {
                    return const Text(
                      'No confirmed players yet.',
                      style: AppTextStyles.bodyMuted,
                    );
                  }

                  return Column(
                    children: participants
                        .map(
                          (participant) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColours.accent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${participant.fullName} - ${participant.position}',
                                    style: AppTextStyles.bodyMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColours.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Payment $label',
        style: AppTextStyles.small.copyWith(color: AppColours.accent),
      ),
    );
  }
}
