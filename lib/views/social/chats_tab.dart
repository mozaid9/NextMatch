import 'package:flutter/material.dart';

import '../../core/widgets/empty_state.dart';
import '../../models/app_user.dart';

/// Placeholder — the real chat list comes in the next pass.
class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: EmptyState(
        icon: Icons.forum_outlined,
        title: 'Chats coming soon',
        message:
            'Direct message your friends here. Tap a friend to start a chat once this is ready.',
      ),
    );
  }
}
