import 'package:flutter/material.dart';

import '../../core/widgets/empty_state.dart';
import '../../models/app_user.dart';

/// Placeholder — team creation and chat come in the next pass.
class TeamsTab extends StatelessWidget {
  const TeamsTab({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: EmptyState(
        icon: Icons.shield_outlined,
        title: 'Teams coming soon',
        message:
            'Create or join a team, manage your roster and chat with your squad.',
      ),
    );
  }
}
