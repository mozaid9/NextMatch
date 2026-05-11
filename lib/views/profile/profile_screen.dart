import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/app_user.dart';
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
              padding: const EdgeInsets.all(20),
              children: [
                Container(
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
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColours.cardAlt,
                            child: Text(
                              user.fullName.isEmpty
                                  ? 'N'
                                  : user.fullName[0].toUpperCase(),
                              style: AppTextStyles.h2.copyWith(
                                color: AppColours.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.fullName, style: AppTextStyles.h2),
                                const SizedBox(height: 4),
                                Text(
                                  '${user.preferredPosition} - ${user.skillLevel}',
                                  style: AppTextStyles.bodyMuted,
                                ),
                                const SizedBox(height: 4),
                                Text(user.location, style: AppTextStyles.small),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(user.bio, style: AppTextStyles.bodyMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Reliability',
                        value: '${user.reliabilityScore}%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: 'Played',
                        value: user.matchesPlayed.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        label: 'Rating',
                        value: user.rating == 0
                            ? 'New'
                            : user.rating.toStringAsFixed(1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailPanel(user: user),
                const SizedBox(height: 16),
                _FuturePanel(),
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
                  onPressed: () => context.read<AuthViewModel>().signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColours.error,
                    side: const BorderSide(color: AppColours.error),
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

class _FuturePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final futureItems = ['Reviews', 'Stats', 'Goals', 'Assists', 'MOTM awards'];

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
          Text('Coming next', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: futureItems
                .map(
                  (item) => Chip(
                    label: Text(item),
                    backgroundColor: AppColours.cardAlt,
                    side: const BorderSide(color: AppColours.line),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
