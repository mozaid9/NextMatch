import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/app_user.dart';
import '../../services/reliability_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: context.watch<ProfileViewModel>().userStream(currentUser.uid),
      initialData: currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data ?? currentUser;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _ProfileHeader(user: user),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: 'Reliability',
                              value:
                                  '${user.reliabilityScore} ${ReliabilityService.getReliabilityLabel(user.reliabilityScore)}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              label: 'Ability',
                              value:
                                  '${user.abilityRating.toStringAsFixed(1)}/5',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              label: 'Ratings',
                              value: user.abilityRatingCount.toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailPanel(user: user),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EditProfileScreen(user: user),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit profile'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.read<AuthViewModel>().signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColours.error,
                          side: const BorderSide(color: AppColours.error),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final initial = user.fullName.isEmpty
        ? 'N'
        : user.fullName[0].toUpperCase();
    final displayName = user.fullName.isEmpty
        ? 'Player'
        : user.fullName
              .split(' ')
              .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
              .join(' ');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColours.card,
        border: Border(bottom: BorderSide(color: AppColours.line)),
      ),
      child: Column(
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColours.accent.withValues(alpha: 0.25),
                  AppColours.accent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -36),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColours.surface,
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColours.cardAlt,
                    child: Text(
                      initial,
                      style: AppTextStyles.h1.copyWith(
                        color: AppColours.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(displayName, style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(
                  '${user.preferredPosition} · ${user.skillLevel}',
                  style: AppTextStyles.bodyMuted,
                ),
                if (user.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: AppColours.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Text(user.location, style: AppTextStyles.small),
                    ],
                  ),
                ],
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      user.bio,
                      style: AppTextStyles.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.h3.copyWith(color: AppColours.accent),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.small),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Player details', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          _DetailRow(label: 'Age', value: user.age.toString()),
          _DetailRow(
            label: 'Preferred position',
            value: user.preferredPosition,
          ),
          _DetailRow(
            label: 'Secondary position',
            value: user.secondaryPosition,
          ),
          _DetailRow(label: 'Favourite foot', value: user.favouriteFoot),
          _DetailRow(
            label: 'Completed matches',
            value: user.completedMatches.toString(),
          ),
          _DetailRow(
            label: 'Attended matches',
            value: user.attendedMatches.toString(),
          ),
          _DetailRow(label: 'No-shows', value: user.noShows.toString()),
          _DetailRow(
            label: 'Late cancellations',
            value: user.lateCancellations.toString(),
          ),
          _DetailRow(
            label: 'Cancelled matches',
            value: user.cancelledMatches.toString(),
          ),
          _DetailRow(
            label: 'Ability rating',
            value:
                '${user.abilityRating.toStringAsFixed(1)}/5 from ${user.abilityRatingCount} ratings',
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMuted)),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
