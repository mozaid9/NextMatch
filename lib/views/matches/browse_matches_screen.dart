import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/match_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
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

  @override
  Widget build(BuildContext context) {
    final matchViewModel = context.watch<MatchViewModel>();

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
                  Text('Open football nearby', style: AppTextStyles.h1),
                  const SizedBox(height: 8),
                  Text(
                    'Find a game, pick your position and secure your spot.',
                    style: AppTextStyles.bodyMuted,
                  ),
                  const SizedBox(height: 16),
                  _FilterWrap(
                    format: _format,
                    skill: _skill,
                    distance: _distance,
                    date: _date,
                    position: _position,
                    onFormatChanged: (value) => setState(() => _format = value),
                    onSkillChanged: (value) => setState(() => _skill = value),
                    onDistanceChanged: (value) =>
                        setState(() => _distance = value),
                    onDateChanged: (value) => setState(() => _date = value),
                    onPositionChanged: (value) =>
                        setState(() => _position = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<FootballMatch>>(
                stream: matchViewModel.openMatchesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColours.accent,
                      ),
                    );
                  }

                  final filtered = _applyFilters(snapshot.data ?? []);
                  if (filtered.isEmpty) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: 'No matches found',
                        message:
                            'Try loosening the filters or add sample games for the MVP demo.',
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
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final match = filtered[index];
                      return MatchCard(
                        match: match,
                        actionLabel: match.isFull ? 'View' : 'Join',
                        onActionPressed: () => _openDetail(match),
                        onTap: () => _openDetail(match),
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
    return matches.where((match) {
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

class _FilterWrap extends StatelessWidget {
  const _FilterWrap({
    required this.format,
    required this.skill,
    required this.distance,
    required this.date,
    required this.position,
    required this.onFormatChanged,
    required this.onSkillChanged,
    required this.onDistanceChanged,
    required this.onDateChanged,
    required this.onPositionChanged,
  });

  final String format;
  final String skill;
  final String distance;
  final String date;
  final String position;
  final ValueChanged<String> onFormatChanged;
  final ValueChanged<String> onSkillChanged;
  final ValueChanged<String> onDistanceChanged;
  final ValueChanged<String> onDateChanged;
  final ValueChanged<String> onPositionChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PopupFilter(
          icon: Icons.groups_2,
          label: format,
          options: const ['Any format', ...AppStrings.matchFormats],
          onSelected: onFormatChanged,
        ),
        _PopupFilter(
          icon: Icons.bolt,
          label: skill,
          options: const ['Any skill', ...AppStrings.skillLevels],
          onSelected: onSkillChanged,
        ),
        _PopupFilter(
          icon: Icons.near_me_outlined,
          label: distance,
          options: const ['Any distance', 'Under 2 miles', 'Under 5 miles'],
          onSelected: onDistanceChanged,
        ),
        _PopupFilter(
          icon: Icons.event,
          label: date,
          options: const ['Any date', 'Today', 'This week'],
          onSelected: onDateChanged,
        ),
        _PopupFilter(
          icon: Icons.sports,
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
    );
  }
}

class _PopupFilter extends StatelessWidget {
  const _PopupFilter({
    required this.icon,
    required this.label,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppColours.card,
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map(
            (option) =>
                PopupMenuItem<String>(value: option, child: Text(option)),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColours.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColours.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColours.accent),
            const SizedBox(width: 7),
            Text(label, style: AppTextStyles.small),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16),
          ],
        ),
      ),
    );
  }
}
