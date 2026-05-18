import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/match_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../matches/match_detail_screen.dart';
import '../matches/my_matches_screen.dart';
import '../venues/browse_venues_screen.dart';

class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColours.accent,
          backgroundColor: AppColours.card,
          onRefresh: _onRefresh,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                                'Hi, ${_capitalise(widget.currentUser.fullName.split(' ').first)}',
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
                            widget.currentUser.fullName.isEmpty
                                ? 'N'
                                : widget.currentUser.fullName[0].toUpperCase(),
                            style: AppTextStyles.h3.copyWith(
                              color: AppColours.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _QuickActions(
                      onCreateMatch: widget.onCreateMatch,
                      onBrowseMatches: widget.onBrowseMatches,
                      onMyMatches: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MyMatchesScreen(currentUser: widget.currentUser),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BookPitchCard(currentUser: widget.currentUser),
                    _CoPlayersStrip(uid: widget.currentUser.uid),
                    Text('Your next match', style: AppTextStyles.h2),
                    const SizedBox(height: 12),
                    _UpcomingJoinedMatch(currentUser: widget.currentUser),
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
                          onPressed: widget.onBrowseMatches,
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
                    child: SkeletonMatchList(
                      count: 3,
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 112),
                    ),
                  );
                }

                final matches = (snapshot.data ?? []).take(3).toList();
                if (matches.isEmpty) {
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
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
                                .seedDemoMatches(widget.currentUser);
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                  sliver: SliverList.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      return MatchCard(
                        match: match,
                        onTap: () => _openMatch(context, match),
                      );
                    },
                  ),
                );
              },
            ),
          ],
          ),   // CustomScrollView
        ),     // RefreshIndicator
      ),       // SafeArea
    );
  }

  void _openMatch(BuildContext context, FootballMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MatchDetailScreen(matchId: match.id, currentUser: widget.currentUser),
      ),
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCreateMatch,
    required this.onBrowseMatches,
    required this.onMyMatches,
  });

  final VoidCallback onCreateMatch;
  final VoidCallback onBrowseMatches;
  final VoidCallback onMyMatches;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.add_circle_outline,
            label: 'Create',
            onTap: onCreateMatch,
            isPrimary: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.search,
            label: 'Find a game',
            onTap: onBrowseMatches,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.calendar_month_outlined,
            label: 'My matches',
            onTap: onMyMatches,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColours.accent.withValues(alpha: 0.12)
              : AppColours.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary ? AppColours.accent.withValues(alpha: 0.4) : AppColours.line,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isPrimary ? AppColours.accent : AppColours.mutedText,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.small.copyWith(
                color: isPrimary ? AppColours.accent : AppColours.text,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookPitchCard extends StatelessWidget {
  const _BookPitchCard({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BrowseVenuesScreen(currentUser: currentUser),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColours.accent.withValues(alpha: 0.4)),
          gradient: LinearGradient(
            colors: [
              AppColours.accent.withValues(alpha: 0.16),
              AppColours.accent.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColours.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.stadium,
                color: AppColours.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('Book a pitch', style: AppTextStyles.h3),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColours.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF071014),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Browse partner venues and book a slot in seconds.',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColours.accent),
          ],
        ),
      ),
    );
  }
}

class _CoPlayersStrip extends StatelessWidget {
  const _CoPlayersStrip({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.read<MatchViewModel>();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: matchViewModel.getFrequentCoPlayers(uid),
      builder: (context, snapshot) {
        final players = snapshot.data ?? [];
        if (players.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 26),
            Text('Players you run with', style: AppTextStyles.h2),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: players.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _CoPlayerCard(player: players[index]),
              ),
            ),
            const SizedBox(height: 26),
          ],
        );
      },
    );
  }
}

class _CoPlayerCard extends StatelessWidget {
  const _CoPlayerCard({required this.player});

  final Map<String, dynamic> player;

  @override
  Widget build(BuildContext context) {
    final name = player['fullName'] as String? ?? '';
    final count = player['count'] as int? ?? 0;
    final firstName = name.split(' ').first;
    final initial =
        firstName.isEmpty ? '?' : firstName[0].toUpperCase();

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColours.accent.withValues(alpha: 0.14),
            child: Text(
              initial,
              style: AppTextStyles.body.copyWith(
                color: AppColours.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            firstName,
            style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            '$count ${count == 1 ? "game" : "games"}',
            style: AppTextStyles.small.copyWith(color: AppColours.mutedText),
            maxLines: 1,
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
            title: 'No games yet',
            message: 'Join a match and it will appear here.',
          );
        }

        final summary = upcoming.first;
        final paymentStatus = summary['paymentStatus'] as String? ?? '';
        final isPendingPayment = paymentStatus == 'PendingPayment';
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
                  color:
                      (isPendingPayment
                              ? AppColours.warning
                              : AppColours.accent)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPendingPayment ? 'Payment pending' : 'Spot secured',
                  style: TextStyle(
                    color: isPendingPayment
                        ? AppColours.warning
                        : AppColours.accent,
                    fontSize: 12,
                  ),
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
