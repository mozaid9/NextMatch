import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/match_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../matches/match_detail_screen.dart';
import '../matches/my_matches_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.onCreateMatch,
    required this.onBrowseMatches,
  });

  final AppUser currentUser;
  final VoidCallback onCreateMatch;
  final VoidCallback onBrowseMatches;

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${currentUser.fullName.split(' ').first}',
                                style: AppTextStyles.h1,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Ready for your next game?',
                                style: AppTextStyles.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColours.cardAlt,
                          child: Text(
                            currentUser.fullName.isEmpty
                                ? 'N'
                                : currentUser.fullName[0].toUpperCase(),
                            style: AppTextStyles.h3.copyWith(
                              color: AppColours.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SearchCard(onBrowseMatches: onBrowseMatches),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Create Match',
                            icon: Icons.add,
                            onPressed: onCreateMatch,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'My matches',
                            icon: Icons.calendar_month,
                            isSecondary: true,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      MyMatchesScreen(currentUser: currentUser),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text('Upcoming joined match', style: AppTextStyles.h2),
                    const SizedBox(height: 12),
                    _UpcomingJoinedMatch(currentUser: currentUser),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Nearby open matches',
                            style: AppTextStyles.h2,
                          ),
                        ),
                        TextButton(
                          onPressed: onBrowseMatches,
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            StreamBuilder<List<FootballMatch>>(
              stream: matchViewModel.openMatchesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(
                          color: AppColours.accent,
                        ),
                      ),
                    ),
                  );
                }

                final matches = (snapshot.data ?? []).take(3).toList();
                if (matches.isEmpty) {
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.sports_soccer,
                        title: 'No open matches yet',
                        message:
                            'Create the first game or add demo matches to explore the flow.',
                        action: PrimaryButton(
                          label: 'Add demo matches',
                          icon: Icons.auto_awesome,
                          isLoading: matchViewModel.isLoading,
                          onPressed: () async {
                            final success = await matchViewModel
                                .seedDemoMatches(currentUser);
                            if (!context.mounted || !success) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Demo matches added.'),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      return MatchCard(
                        match: match,
                        actionLabel: 'View',
                        onActionPressed: () => _openMatch(context, match),
                        onTap: () => _openMatch(context, match),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openMatch(BuildContext context, FootballMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MatchDetailScreen(matchId: match.id, currentUser: currentUser),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.onBrowseMatches});

  final VoidCallback onBrowseMatches;

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
          Text('Find a game nearby', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Filter by format, skill level, date and needed position.',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onBrowseMatches,
            icon: const Icon(Icons.tune),
            label: const Text('Search matches'),
          ),
        ],
      ),
    );
  }
}

class _UpcomingJoinedMatch extends StatelessWidget {
  const _UpcomingJoinedMatch({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: matchViewModel.joinedMatchSummariesStream(currentUser.uid),
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? [];
        final upcoming = summaries.where((summary) {
          final value = summary['matchDateTime'];
          final date = value is Timestamp ? value.toDate() : DateTime.now();
          return date.isAfter(
            DateTime.now().subtract(const Duration(hours: 2)),
          );
        }).toList();

        if (upcoming.isEmpty) {
          return const EmptyState(
            icon: Icons.event_available,
            title: 'No confirmed games',
            message: 'Join a match and it will appear here.',
          );
        }

        final summary = upcoming.first;
        return FutureBuilder<FootballMatch?>(
          future: matchViewModel.getMatch(summary['matchId'] as String),
          builder: (context, matchSnapshot) {
            final match = matchSnapshot.data;
            if (match == null) {
              return const EmptyState(
                icon: Icons.event_busy,
                title: 'Loading your match',
                message: 'Your next confirmed game is being fetched.',
              );
            }

            return MatchCard(
              match: match,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColours.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Payment confirmed',
                  style: TextStyle(color: AppColours.accent, fontSize: 12),
                ),
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
            );
          },
        );
      },
    );
  }
}
