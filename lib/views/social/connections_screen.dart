import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../services/friends_service.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../profile/other_user_profile_screen.dart';

enum ConnectionsMode { following, followers }

/// Full-screen list of people the [user] follows or who follow them.
class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({
    super.key,
    required this.user,
    required this.viewer,
    required this.mode,
  });

  /// Whose connections we're viewing (often the same as [viewer], but
  /// could be a different player when viewing their profile).
  final AppUser user;

  /// The currently signed-in user — used as the viewer for tap-through.
  final AppUser viewer;

  final ConnectionsMode mode;

  @override
  Widget build(BuildContext context) {
    final friendsViewModel = context.watch<FriendsViewModel>();
    final stream = mode == ConnectionsMode.following
        ? friendsViewModel.followingStream(user.uid)
        : friendsViewModel.followersStream(user.uid);

    final isFollowing = mode == ConnectionsMode.following;
    final title = isFollowing ? 'Following' : 'Followers';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<List<Friend>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColours.accent),
            );
          }
          final list = snapshot.data ?? const <Friend>[];
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: EmptyState(
                icon: isFollowing
                    ? Icons.person_outline
                    : Icons.group_outlined,
                title: isFollowing ? 'Not following anyone yet' : 'No followers yet',
                message: isFollowing
                    ? 'Search players or tap follow on a profile to start.'
                    : 'When someone follows this account, they\'ll appear here.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final person = list[index];
              return _ConnectionTile(
                person: person,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OtherUserProfileScreen(
                      uid: person.uid,
                      viewer: viewer,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({required this.person, required this.onTap});

  final Friend person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColours.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColours.line),
        ),
        child: Row(
          children: [
            UserAvatar(
              fullName: person.fullName,
              photoUrl: person.photoUrl,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.fullName,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${person.position} · ${person.skillLevel}',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColours.mutedText,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
