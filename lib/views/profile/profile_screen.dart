import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../services/notification_service.dart';
import '../../services/reliability_service.dart';
import '../../services/friends_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../settings/settings_screen.dart';
import '../social/friends_screen.dart';
import 'edit_profile_screen.dart';

Color _reliabilityColor(int score) {
  if (score >= 75) return AppColours.accent;
  if (score >= 60) return AppColours.warning;
  return AppColours.error;
}

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
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(currentUser: user),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _ProfileHeader(user: user),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    children: [
                      _StatsCard(user: user),
                      const SizedBox(height: 16),
                      _DetailPanel(user: user),
                      const SizedBox(height: 20),
                      StreamBuilder<List<Friend>>(
                        stream: context.read<FriendsViewModel>().friendsStream(
                          user.uid,
                        ),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.length ?? 0;
                          return OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      FriendsScreen(currentUser: user),
                                ),
                              );
                            },
                            icon: const Icon(Icons.group_outlined),
                            label: Text(
                              count == 0 ? 'Friends' : 'Friends · $count',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
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
                        onPressed: () async {
                          final confirmed = await showAppConfirmSheet(
                            context: context,
                            title: 'Sign out?',
                            message:
                                'You can log back in with the same account any time.',
                            confirmLabel: 'Sign out',
                            confirmIcon: Icons.logout,
                            isDestructive: true,
                          );
                          if (confirmed != true || !context.mounted) return;
                          // Stop this device receiving pushes for the
                          // account being signed out.
                          await context
                              .read<NotificationService>()
                              .unregister();
                          if (!context.mounted) return;
                          await context.read<AuthViewModel>().signOut();
                        },
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
    final displayName = user.fullName.isEmpty
        ? 'Player'
        : user.fullName
              .split(' ')
              .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
              .join(' ');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColours.card,
        border: Border(bottom: BorderSide(color: AppColours.line)),
      ),
      child: Column(
        children: [
          // Banner with avatar overlapping its bottom edge
          SizedBox(
            height: 120, // 80px banner + 40px (lower half of avatar)
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
                  top: 40, // banner_height - avatar_radius = 80 - 40
                  child: _AvatarUploader(user: user),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(displayName, style: AppTextStyles.h2),
          if (user.hasUsername) ...[
            const SizedBox(height: 2),
            Text(
              '@${user.username}',
              style: AppTextStyles.small.copyWith(color: AppColours.accent),
            ),
          ],
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
                Icon(
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final hasHistory = user.hasReliabilityHistory;
    final relColor =
        hasHistory ? _reliabilityColor(user.reliabilityScore) : AppColours.mutedText;
    final relLabel = hasHistory
        ? ReliabilityService.getReliabilityLabel(user.reliabilityScore)
        : 'New player';

    return Container(
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColours.line),
      ),
      child: Column(
        children: [
          // Thin coloured accent bar at top
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: relColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                // Matches played
                Expanded(
                  child: _StatBlock(
                    value: user.completedMatches.toString(),
                    label: 'Matches',
                  ),
                ),
                _vDivider,
                // Ability rating
                Expanded(
                  child: _StatBlock(
                    value: user.abilityRatingCount > 0
                        ? user.abilityRating.toStringAsFixed(1)
                        : '-',
                    label: 'Ability',
                    subLabel: user.abilityRatingCount > 0
                        ? '${user.abilityRatingCount} ${user.abilityRatingCount == 1 ? "rating" : "ratings"}'
                        : 'Not rated',
                  ),
                ),
                _vDivider,
                // Reliability arc
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
                              value: hasHistory
                                  ? user.reliabilityScore / 100
                                  : 0,
                              strokeWidth: 5,
                              strokeCap: StrokeCap.round,
                              backgroundColor: AppColours.line,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                relColor,
                              ),
                            ),
                            Text(
                              hasHistory ? '${user.reliabilityScore}' : '—',
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

  Widget get _vDivider =>
      Container(width: 1, height: 56, color: AppColours.line);
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label, this.subLabel});
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
          _DetailRow(label: 'Age', value: user.computedAge.toString()),
          _DetailRow(
            label: 'Preferred position',
            value: user.preferredPosition,
          ),
          if (user.secondaryPosition.isNotEmpty &&
              user.secondaryPosition != 'Any')
            _DetailRow(
              label: 'Secondary position',
              value: user.secondaryPosition,
            ),
          _DetailRow(label: 'Favourite foot', value: user.favouriteFoot),
          _DetailRow(
            label: 'Matches played',
            value: user.completedMatches.toString(),
          ),
          if (user.noShows > 0)
            _DetailRow(label: 'No-shows', value: user.noShows.toString()),
          if (user.lateCancellations > 0)
            _DetailRow(
              label: 'Late cancellations',
              value: user.lateCancellations.toString(),
            ),
          if (user.cancelledMatches > 0)
            _DetailRow(
              label: 'Cancelled matches',
              value: user.cancelledMatches.toString(),
            ),
          if (user.abilityRatingCount > 0)
            _DetailRow(
              label: 'Ability rating',
              value:
                  '${user.abilityRating.toStringAsFixed(1)}/5 (${user.abilityRatingCount} ratings)',
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

/// Profile header avatar with a tap-to-upload affordance.
class _AvatarUploader extends StatefulWidget {
  const _AvatarUploader({required this.user});

  final AppUser user;

  @override
  State<_AvatarUploader> createState() => _AvatarUploaderState();
}

class _AvatarUploaderState extends State<_AvatarUploader> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;

    XFile? file;
    try {
      final picker = ImagePicker();
      file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open photo picker: $error')),
      );
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;

      final profileViewModel = context.read<ProfileViewModel>();
      final url = await profileViewModel
          .uploadProfilePhoto(
            uid: widget.user.uid,
            bytes: bytes,
            contentType: file.mimeType ?? 'image/jpeg',
          )
          .timeout(const Duration(seconds: 30), onTimeout: () => null);

      if (!mounted) return;
      if (url == null) {
        final reason =
            profileViewModel.errorMessage ??
            'Upload timed out. Check Firebase Storage CORS and rules.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reason), duration: const Duration(seconds: 6)),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $error'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pickAndUpload,
        child: SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              UserAvatar(
                fullName: widget.user.fullName,
                photoUrl: widget.user.photoUrl,
                radius: 40,
                borderColor: AppColours.surface,
              ),
              if (_uploading)
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColours.accent,
                    ),
                  ),
                ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColours.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColours.surface, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: Color(0xFF071014),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
