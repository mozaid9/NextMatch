import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/match_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/selection_sheet.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../services/friends_service.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../viewmodels/match_viewmodel.dart';
import 'match_detail_screen.dart';
import 'my_matches_screen.dart';

class BrowseMatchesScreen extends StatefulWidget {
  const BrowseMatchesScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<BrowseMatchesScreen> createState() => _BrowseMatchesScreenState();
}

class _BrowseMatchesScreenState extends State<BrowseMatchesScreen> {
  String _format = 'Any format';
  String _skill = 'Any skill';
  String _distance = 'Any distance';
  String _date = 'Any date';
  String _position = 'Any position';
  String _sort = 'Soonest';

  Future<void> _onRefresh() async {
    // Stream is live — brief delay gives visual feedback
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  bool get _hasActiveFilters =>
      _format != 'Any format' ||
      _skill != 'Any skill' ||
      _distance != 'Any distance' ||
      _date != 'Any date' ||
      _position != 'Any position';

  void _clearFilters() => setState(() {
        _format = 'Any format';
        _skill = 'Any skill';
        _distance = 'Any distance';
        _date = 'Any date';
        _position = 'Any position';
      });

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();
    final friendsViewModel = context.read<FriendsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        actions: [
          IconButton(
            tooltip: 'My matches',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      MyMatchesScreen(currentUser: widget.currentUser),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterRow(
                    format: _format,
                    skill: _skill,
                    distance: _distance,
                    date: _date,
                    position: _position,
                    sort: _sort,
                    onFormatChanged: (value) => setState(() => _format = value),
                    onSkillChanged: (value) => setState(() => _skill = value),
                    onDistanceChanged: (value) =>
                        setState(() => _distance = value),
                    onDateChanged: (value) => setState(() => _date = value),
                    onPositionChanged: (value) =>
                        setState(() => _position = value),
                    onSortChanged: (value) => setState(() => _sort = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Friend>>(
                stream: friendsViewModel.friendsStream(widget.currentUser.uid),
                builder: (context, friendsSnap) {
                  final friendUids = (friendsSnap.data ?? const <Friend>[])
                      .map((f) => f.uid)
                      .toSet();
                  return StreamBuilder<List<FootballMatch>>(
                stream: matchViewModel.openMatchesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SkeletonMatchList();
                  }

                  final filtered = _applyFilters(snapshot.data ?? []);
                  if (filtered.isEmpty) {
                    return RefreshIndicator(
                      color: AppColours.accent,
                      backgroundColor: AppColours.card,
                      onRefresh: _onRefresh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
                        child: EmptyState(
                          icon: _hasActiveFilters
                              ? Icons.filter_alt_off
                              : Icons.search_off,
                          title: _hasActiveFilters
                              ? 'No matches for these filters'
                              : 'No matches found',
                          message: _hasActiveFilters
                              ? 'Try broadening your search, or clear all filters to see everything.'
                              : 'Be the first to post a game in your area.',
                          action: _hasActiveFilters
                              ? PrimaryButton(
                                  label: 'Clear all filters',
                                  icon: Icons.filter_alt_off,
                                  isSecondary: true,
                                  onPressed: _clearFilters,
                                )
                              : PrimaryButton(
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

                  return RefreshIndicator(
                    color: AppColours.accent,
                    backgroundColor: AppColours.card,
                    onRefresh: _onRefresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final match = filtered[index];
                        return MatchCard(
                          match: match,
                          onTap: () => _openDetail(match),
                          friendUids: friendUids,
                        );
                      },
                    ),
                  );
                },
              );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FootballMatch> _applyFilters(List<FootballMatch> matches) {
    final filtered = matches.where((match) {
      if (_format != 'Any format' && match.format != _format) return false;
      if (_skill != 'Any skill' && match.skillLevel != _skill) return false;
      if (_position != 'Any position') {
        final key = switch (_position) {
          'Goalkeeper' => 'Goalkeepers',
          'Defender' => 'Defenders',
          'Midfielder' => 'Midfielders',
          'Forward' => 'Forwards',
          _ => '',
        };
        if ((match.neededPositions[key] ?? 0) <= 0) return false;
      }
      if (_date == 'Today' &&
          !_isSameDay(match.startDateTime, DateTime.now())) {
        return false;
      }
      if (_date == 'This week' &&
          match.startDateTime.isAfter(
            DateTime.now().add(const Duration(days: 7)),
          )) {
        return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case 'Soonest':
        filtered.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      case 'Latest':
        filtered.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
      case 'Cheapest':
        filtered.sort((a, b) => a.pricePerPlayer.compareTo(b.pricePerPlayer));
      case 'Most filled':
        filtered.sort((a, b) {
          final aRatio = a.joinedPlayerCount / a.totalPlayersNeeded;
          final bRatio = b.joinedPlayerCount / b.totalPlayersNeeded;
          return bRatio.compareTo(aRatio);
        });
    }
    return filtered;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _openDetail(FootballMatch match) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchDetailScreen(
          matchId: match.id,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.format,
    required this.skill,
    required this.distance,
    required this.date,
    required this.position,
    required this.sort,
    required this.onFormatChanged,
    required this.onSkillChanged,
    required this.onDistanceChanged,
    required this.onDateChanged,
    required this.onPositionChanged,
    required this.onSortChanged,
  });

  final String format;
  final String skill;
  final String distance;
  final String date;
  final String position;
  final String sort;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<String> onSkillChanged;
  final ValueChanged<String> onDistanceChanged;
  final ValueChanged<String> onDateChanged;
  final ValueChanged<String> onPositionChanged;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _PopupFilter(
            icon: Icons.sort,
            title: 'Sort by',
            label: sort,
            options: const ['Soonest', 'Latest', 'Cheapest', 'Most filled'],
            onSelected: onSortChanged,
            alwaysActive: true,
          ),
          const SizedBox(width: 8),
          _PopupFilter(
            icon: Icons.groups_2,
            title: 'Format',
            label: format,
            options: const ['Any format', ...AppStrings.matchFormats],
            onSelected: onFormatChanged,
          ),
          const SizedBox(width: 8),
          _PopupFilter(
            icon: Icons.bolt,
            title: 'Skill level',
            label: skill,
            options: const ['Any skill', ...AppStrings.skillLevels],
            onSelected: onSkillChanged,
          ),
          const SizedBox(width: 8),
          _PopupFilter(
            icon: Icons.near_me_outlined,
            title: 'Distance',
            label: distance,
            options: const ['Any distance', 'Under 2 miles', 'Under 5 miles'],
            onSelected: onDistanceChanged,
          ),
          const SizedBox(width: 8),
          _PopupFilter(
            icon: Icons.event,
            title: 'Date',
            label: date,
            options: const ['Any date', 'Today', 'This week'],
            onSelected: onDateChanged,
          ),
          const SizedBox(width: 8),
          _PopupFilter(
            icon: Icons.sports,
            title: 'Position',
            label: position,
            options: const [
              'Any position',
              'Goalkeeper',
              'Defender',
              'Midfielder',
              'Forward',
            ],
            onSelected: onPositionChanged,
          ),
        ],
      ),
    );
  }
}

class _PopupFilter extends StatelessWidget {
  const _PopupFilter({
    required this.icon,
    required this.title,
    required this.label,
    required this.options,
    required this.onSelected,
    this.alwaysActive = false,
  });

  final IconData icon;
  final String title;
  final String label;
  final List<String> options;
  final ValueChanged<String> onSelected;
  /// Render the chip in the active style even when on the default value
  /// — useful for "Sort" where the user always picks something.
  final bool alwaysActive;

  @override
  Widget build(BuildContext context) {
    final isActive = alwaysActive || !label.startsWith('Any');

    return InkWell(
      onTap: () => _openOptions(context),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? AppColours.accent.withValues(alpha: 0.08)
              : AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColours.accent.withValues(alpha: 0.6)
                : AppColours.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColours.accent),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.small.copyWith(
                color: isActive ? AppColours.accent : null,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 16,
              color: isActive ? AppColours.accent : AppColours.mutedText,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOptions(BuildContext context) async {
    final selected = await showSelectionSheet(
      context: context,
      title: title,
      selectedValue: label,
      options: options,
    );

    if (selected != null) onSelected(selected);
  }
}
