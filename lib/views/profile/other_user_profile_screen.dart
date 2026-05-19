import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../services/friends_service.dart';
import '../../services/reliability_service.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../social/chat_thread_screen.dart';

/// Read-only view of another player's profile. Shown when tapping a
/// friend in the friends list or a participant tile on a match.
class OtherUserProfileScreen extends StatelessWidget {
  const OtherUserProfileScreen({
    super.key,
    required this.uid,
    this.viewer,
  });

  final String uid;
  /// When provided, a "Message" button appears that opens the 1:1 chat
  /// between [viewer] and this user.
  final AppUser? viewer;

  @override
  Widget build(BuildContext context) {
    final profileViewModel = context.watch<ProfileViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Player profile')),
      body: StreamBuilder<AppUser?>(
        stream: profileViewModel.userStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColours.accent),
            );
          }
          final user = snapshot.data;
          if (user == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Player not found',
                message: 'This account may have been deleted.',
              ),
            );
          }

          return SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _Header(user: user),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    children: [
                      if (viewer != null && viewer!.uid != user.uid) ...[
                        _FollowButton(viewer: viewer!, target: user),
                        const SizedBox(height: 10),
                        PrimaryButton(
                          label: 'Message ${user.fullName.split(' ').first}',
                          icon: Icons.chat_bubble_outline,
                          isSecondary: true,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatThreadScreen(
                                currentUser: viewer!,
                                otherUid: user.uid,
                                otherName: user.fullName,
                                otherPhotoUrl: user.photoUrl,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _StatsCard(user: user),
                      const SizedBox(height: 16),
                      _DetailPanel(user: user),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.viewer, required this.target});

  final AppUser viewer;
  final AppUser target;

  @override
  Widget build(BuildContext context) {
    final friendsViewModel = context.watch<FriendsViewModel>();

    return StreamBuilder<FollowStatus>(
      stream: friendsViewModel.followStatusStream(
        viewerUid: viewer.uid,
        targetUid: target.uid,
      ),
      builder: (context, snapshot) {
        final status = snapshot.data ?? FollowStatus.notFollowing;
        final isLoading = friendsViewModel.isLoading;

        final (label, icon) = switch (status) {
          FollowStatus.notFollowing => ('Follow', Icons.person_add_alt_1),
          FollowStatus.following => ('Following', Icons.check),
          FollowStatus.mutual => ('Friends · Following', Icons.people_alt),
        };

        Future<void> onTap() async {
          if (status == FollowStatus.notFollowing) {
            final ok = await friendsViewModel.follow(
              me: viewer,
              target: target,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? 'Following ${target.fullName.split(' ').first}.'
                      : friendsViewModel.errorMessage ?? 'Could not follow.',
                ),
              ),
            );
          } else {
            // Following or mutual — confirm before unfollowing.
            final confirmed = await showAppConfirmSheet(
              context: context,
              title: 'Unfollow ${target.fullName.split(' ').first}?',
              message: status == FollowStatus.mutual
                  ? "You'll no longer be friends. They'll still follow you unless they unfollow back."
                  : 'You can follow them again anytime.',
              confirmLabel: 'Unfollow',
              confirmIcon: Icons.person_remove_alt_1_outlined,
              isDestructive: true,
            );
            if (confirmed != true) return;
            final ok = await friendsViewModel.unfollow(
              myUid: viewer.uid,
              targetUid: target.uid,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? 'Unfollowed ${target.fullName.split(' ').first}.'
                      : friendsViewModel.errorMessage ??
                          'Could not unfollow.',
                ),
              ),
            );
          }
        }

        return PrimaryButton(
          label: label,
          icon: icon,
          isLoading: isLoading,
          isSecondary: status != FollowStatus.notFollowing,
          onPressed: onTap,
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
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
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
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
                ),
                Positioned(
                  top: 40,
                  child: UserAvatar(
                    fullName: user.fullName,
                    photoUrl: user.photoUrl,
                    radius: 40,
                    borderColor: AppColours.surface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                const Icon(Icons.place_outlined,
                    size: 14, color: AppColours.mutedText),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.user});
  final AppUser user;

  Color _reliabilityColor(int score) {
    if (score >= 75) return AppColours.accent;
    if (score >= 60) return AppColours.warning;
    return AppColours.error;
  }

  @override
  Widget build(BuildContext context) {
    final relColor = _reliabilityColor(user.reliabilityScore);
    final relLabel =
        ReliabilityService.getReliabilityLabel(user.reliabilityScore);

    return Container(
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: relColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: user.completedMatches.toString(),
                    label: 'Matches',
                  ),
                ),
                Container(width: 1, height: 56, color: AppColours.line),
                Expanded(
                  child: _Stat(
                    value: user.abilityRatingCount > 0
                        ? user.abilityRating.toStringAsFixed(1)
                        : '—',
                    label: 'Ability',
                    subLabel: user.abilityRatingCount > 0
                        ? '${user.abilityRatingCount} ratings'
                        : 'Not rated',
                  ),
                ),
                Container(width: 1, height: 56, color: AppColours.line),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: user.reliabilityScore / 100,
                              strokeWidth: 5,
                              strokeCap: StrokeCap.round,
                              backgroundColor: AppColours.line,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(relColor),
                            ),
                            Text(
                              '${user.reliabilityScore}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: relColor,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        relLabel,
                        style: AppTextStyles.small.copyWith(
                          color: relColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Reliability', style: AppTextStyles.small),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.subLabel});
  final String value;
  final String label;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.h2),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.small, textAlign: TextAlign.center),
        if (subLabel != null)
          Text(
            subLabel!,
            style: AppTextStyles.small.copyWith(color: AppColours.mutedText),
            textAlign: TextAlign.center,
          ),
      ],
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
          _row('Preferred position', user.preferredPosition),
          if (user.secondaryPosition.isNotEmpty &&
              user.secondaryPosition != 'Any')
            _row('Secondary position', user.secondaryPosition),
          _row('Favourite foot', user.favouriteFoot),
          _row('Matches played', user.completedMatches.toString()),
          if (user.abilityRatingCount > 0)
            _row(
              'Ability rating',
              '${user.abilityRating.toStringAsFixed(1)}/5 (${user.abilityRatingCount} ratings)',
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodyMuted)),
            Text(value, style: AppTextStyles.body),
          ],
        ),
      );
}
