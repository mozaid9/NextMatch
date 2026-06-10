import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/match_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../services/friends_service.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../viewmodels/match_viewmodel.dart';
import '../../models/team.dart';
import '../../models/venue.dart';
import '../../viewmodels/team_viewmodel.dart';
import '../../viewmodels/venue_viewmodel.dart';
import '../matches/match_detail_screen.dart';
import '../matches/my_matches_screen.dart';
import '../profile/other_user_profile_screen.dart';
import '../social/team_detail_screen.dart';
import '../venues/browse_venues_screen.dart';
import '../venues/venue_detail_screen.dart';

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
                        UserAvatar(
                          fullName: widget.currentUser.fullName,
                          photoUrl: widget.currentUser.photoUrl,
                          radius: 24,
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
                    _MyTeamsStrip(currentUser: widget.currentUser),
                    _SavedVenuesStrip(currentUser: widget.currentUser),
                    _CoPlayersStrip(currentUser: widget.currentUser),
                    _MatchInvitesSection(currentUser: widget.currentUser),
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
            StreamBuilder<List<Friend>>(
              stream: context
                  .read<FriendsViewModel>()
                  .friendsStream(widget.currentUser.uid),
              builder: (context, friendsSnap) {
                final friendUids = (friendsSnap.data ?? const <Friend>[])
                    .map((f) => f.uid)
                    .toSet();
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: matchViewModel.joinedMatchSummariesStream(
                    widget.currentUser.uid,
                  ),
                  builder: (context, joinedSnap) {
                    final joinedIds = (joinedSnap.data ?? const [])
                        .map((s) => s['matchId'] as String? ?? '')
                        .toSet();
                    return StreamBuilder<List<FootballMatch>>(
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

                // Matches you organise or have already joined live under
                // "Your next match" / My matches — don't re-list them as
                // joinable nearby games.
                final matches = (snapshot.data ?? [])
                    .where(
                      (m) =>
                          m.organiserId != widget.currentUser.uid &&
                          !joinedIds.contains(m.id),
                    )
                    .take(3)
                    .toList();
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
                        friendUids: friendUids,
                      );
                    },
                  ),
                );
              },
            );
                  },
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

class _MyTeamsStrip extends StatelessWidget {
  const _MyTeamsStrip({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Team>>(
      stream: context.read<TeamViewModel>().myTeamsStream(currentUser.uid),
      builder: (context, snapshot) {
        final teams = snapshot.data ?? [];
        if (teams.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 26),
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppColours.accent, size: 18),
                const SizedBox(width: 8),
                Text('Your teams', style: AppTextStyles.h2),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: teams.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final team = teams[index];
                  return _MyTeamCard(
                    team: team,
                    currentUser: currentUser,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MyTeamCard extends StatelessWidget {
  const _MyTeamCard({required this.team, required this.currentUser});

  final Team team;
  final AppUser currentUser;

  Color _colour() {
    final hex = team.colour.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final colour = _colour();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TeamDetailScreen(
            teamId: team.id,
            currentUser: currentUser,
          ),
        ),
      ),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColours.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColours.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colour.withValues(alpha: 0.6)),
              ),
              child: Icon(Icons.shield, color: colour, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              team.name,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${team.members.length} member${team.members.length == 1 ? "" : "s"}',
              style: AppTextStyles.small,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedVenuesStrip extends StatelessWidget {
  const _SavedVenuesStrip({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final venueViewModel = context.read<VenueViewModel>();
    return StreamBuilder<Set<String>>(
      stream: venueViewModel.favouriteVenueIdsStream(currentUser.uid),
      builder: (context, snapshot) {
        final ids = snapshot.data ?? const <String>{};
        if (ids.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 26),
            Row(
              children: [
                const Icon(Icons.bookmark,
                    color: AppColours.accent, size: 18),
                const SizedBox(width: 8),
                Text('Saved venues', style: AppTextStyles.h2),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ids.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final venueId = ids.elementAt(index);
                  return _SavedVenueCard(
                    venueId: venueId,
                    currentUser: currentUser,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SavedVenueCard extends StatelessWidget {
  const _SavedVenueCard({required this.venueId, required this.currentUser});

  final String venueId;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Venue?>(
      future: context.read<VenueViewModel>().getVenue(venueId),
      builder: (context, snapshot) {
        final venue = snapshot.data;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: venue == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VenueDetailScreen(
                        venueId: venue.id,
                        currentUser: currentUser,
                      ),
                    ),
                  ),
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColours.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColours.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColours.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.stadium,
                    color: AppColours.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  venue?.name ?? '…',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (venue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    venue.city,
                    style: AppTextStyles.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MatchInvitesSection extends StatelessWidget {
  const _MatchInvitesSection({required this.currentUser});

  final AppUser currentUser;

  /// Invites stop being actionable this long before kick-off.
  static const _expiryWindow = Duration(hours: 2);

  static DateTime? _inviteKickOff(Map<String, dynamic> invite) {
    final value = invite['matchDateTime'];
    return value is Timestamp ? value.toDate() : null;
  }

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.read<MatchViewModel>();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: matchViewModel.matchInvitesStream(currentUser.uid),
      builder: (context, snapshot) {
        final allInvites = snapshot.data ?? [];
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: matchViewModel.joinedMatchSummariesStream(currentUser.uid),
          builder: (context, joinedSnapshot) {
            final joinedIds = (joinedSnapshot.data ?? const [])
                .map((s) => s['matchId'] as String? ?? '')
                .toSet();

            final now = DateTime.now();
            final invites = <Map<String, dynamic>>[];
            final stale = <String>[];
            for (final invite in allInvites) {
              final matchId = invite['matchId'] as String? ?? '';
              final kickOff = _inviteKickOff(invite);
              final expired =
                  kickOff == null ||
                  now.isAfter(kickOff.subtract(_expiryWindow));
              if (expired || joinedIds.contains(matchId)) {
                // Joined or too close to kick-off — quietly clear it.
                if (matchId.isNotEmpty) stale.add(matchId);
              } else {
                invites.add(invite);
              }
            }
            if (stale.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                for (final matchId in stale) {
                  matchViewModel.dismissMatchInvite(
                    uid: currentUser.uid,
                    matchId: matchId,
                  );
                }
              });
            }
            if (invites.isEmpty) return const SizedBox.shrink();
            return _buildSection(invites);
          },
        );
      },
    );
  }

  Widget _buildSection(List<Map<String, dynamic>> invites) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Match invites', style: AppTextStyles.h2),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColours.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${invites.length}',
                    style: const TextStyle(
                      color: Color(0xFF071014),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...invites.map(
              (invite) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MatchInviteCard(
                  invite: invite,
                  currentUser: currentUser,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        );
  }
}

class _MatchInviteCard extends StatelessWidget {
  const _MatchInviteCard({required this.invite, required this.currentUser});

  final Map<String, dynamic> invite;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final matchId = invite['matchId'] as String? ?? '';
    final title = invite['matchTitle'] as String? ?? 'Match';
    final inviter = invite['inviterName'] as String? ?? 'A friend';
    final location = invite['locationName'] as String? ?? '';
    final format = invite['format'] as String? ?? '';
    final whenValue = invite['matchDateTime'];
    final when = whenValue is Timestamp
        ? whenValue.toDate()
        : DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.accent.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          colors: [
            AppColours.accent.withValues(alpha: 0.12),
            AppColours.accent.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_outlined,
                  color: AppColours.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$inviter invited you',
                  style: AppTextStyles.small.copyWith(
                    color: AppColours.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            '$location · $format · ${_formatWhen(when)}',
            style: AppTextStyles.small,
          ),
          if (_expiryLabel(when) != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom,
                  size: 13,
                  color: AppColours.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  _expiryLabel(when)!,
                  style: AppTextStyles.small.copyWith(
                    color: AppColours.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final viewModel = context.read<MatchViewModel>();
                    await viewModel.dismissMatchInvite(
                      uid: currentUser.uid,
                      matchId: matchId,
                    );
                  },
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: 'Accept',
                  icon: Icons.how_to_reg,
                  onPressed: () {
                    // The invite stays until they actually join (the
                    // section clears it automatically once the match
                    // appears in their joined list).
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MatchDetailScreen(
                          matchId: matchId,
                          currentUser: currentUser,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Expires in 5h 12m" once the invite is inside its final 24 hours.
  /// Invites stop being shown 2 hours before kick-off (see
  /// _MatchInvitesSection._expiryWindow).
  String? _expiryLabel(DateTime kickOff) {
    final expiresAt = kickOff.subtract(const Duration(hours: 2));
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative || remaining > const Duration(hours: 24)) {
      return null;
    }
    final hours = remaining.inHours;
    final mins = remaining.inMinutes.remainder(60);
    return hours > 0 ? 'Expires in ${hours}h ${mins}m' : 'Expires in ${mins}m';
  }

  String _formatWhen(DateTime time) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '${time.day} ${months[time.month - 1]} · $h:$m';
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
  const _CoPlayersStrip({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.read<MatchViewModel>();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: matchViewModel.getFrequentCoPlayers(currentUser.uid),
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
                itemBuilder: (context, index) => _CoPlayerCard(
                  player: players[index],
                  currentUser: currentUser,
                ),
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
  const _CoPlayerCard({required this.player, required this.currentUser});

  final AppUser currentUser;

  final Map<String, dynamic> player;

  @override
  Widget build(BuildContext context) {
    final name = player['fullName'] as String? ?? '';
    final uid = player['userId'] as String? ?? '';
    final count = player['count'] as int? ?? 0;
    final firstName = name.split(' ').first;

    return InkWell(
      onTap: uid.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OtherUserProfileScreen(
                    uid: uid,
                    viewer: currentUser,
                  ),
                ),
              ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
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
          UserAvatar(
            fullName: firstName,
            photoUrl: player['photoUrl'] as String?,
            radius: 20,
            backgroundColor: AppColours.accent.withValues(alpha: 0.14),
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
      ),  // close Container child of InkWell
    );
  }
}

class _UpcomingJoinedMatch extends StatelessWidget {
  const _UpcomingJoinedMatch({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();
    final horizon = DateTime.now().subtract(const Duration(hours: 2));

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: matchViewModel.joinedMatchSummariesStream(currentUser.uid),
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? [];
        final upcoming = summaries.where((summary) {
          final attendance = summary['attendanceStatus'] as String? ?? '';
          if (const ['Cancelled', 'LateCancelled', 'Rejected', 'NoShow']
              .contains(attendance)) {
            return false;
          }
          final value = summary['matchDateTime'];
          final date = value is Timestamp ? value.toDate() : DateTime.now();
          return date.isAfter(horizon);
        }).toList();

        return StreamBuilder<List<FootballMatch>>(
          stream: matchViewModel.organisedMatchesStream(currentUser.uid),
          builder: (context, organisedSnapshot) {
            final organisedUpcoming =
                (organisedSnapshot.data ?? const <FootballMatch>[])
                    .where(
                      (m) =>
                          !m.isCancelled &&
                          !m.isCompleted &&
                          m.startDateTime.isAfter(horizon),
                    )
                    .toList()
                  ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

            DateTime? joinedStart;
            if (upcoming.isNotEmpty) {
              final value = upcoming.first['matchDateTime'];
              joinedStart = value is Timestamp ? value.toDate() : null;
            }
            final organisedNext =
                organisedUpcoming.isNotEmpty ? organisedUpcoming.first : null;

            // Prefer whichever kicks off sooner; organised matches count as
            // "your next match" too — you're definitely turning up to those.
            final useOrganised =
                organisedNext != null &&
                (joinedStart == null ||
                    organisedNext.startDateTime.isBefore(joinedStart));

            if (useOrganised) {
              return MatchCard(
                match: organisedNext,
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
                    "You're organising",
                    style: TextStyle(color: AppColours.accent, fontSize: 12),
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MatchDetailScreen(
                        matchId: organisedNext.id,
                        currentUser: currentUser,
                      ),
                    ),
                  );
                },
              );
            }

            if (upcoming.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available,
                title: 'No games yet',
                message: 'Join or create a match and it will appear here.',
              );
            }

            final summary = upcoming.first;
            final paymentStatus = summary['paymentStatus'] as String? ?? '';
            final isPendingPayment = paymentStatus == 'PendingPayment';
            return _JoinedMatchCard(
              matchViewModel: matchViewModel,
              summary: summary,
              isPendingPayment: isPendingPayment,
              currentUser: currentUser,
            );
          },
        );
      },
    );
  }
}

class _JoinedMatchCard extends StatelessWidget {
  const _JoinedMatchCard({
    required this.matchViewModel,
    required this.summary,
    required this.isPendingPayment,
    required this.currentUser,
  });

  final MatchViewModel matchViewModel;
  final Map<String, dynamic> summary;
  final bool isPendingPayment;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
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
  }
}
