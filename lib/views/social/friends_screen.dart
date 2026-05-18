import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../services/friends_service.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../profile/other_user_profile_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final friendsViewModel = context.watch<FriendsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Add friend',
            onPressed: () => _openAddFriendSheet(context),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Friend>>(
          stream: friendsViewModel.friendsStream(currentUser.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColours.accent),
              );
            }

            final friends = snapshot.data ?? [];
            if (friends.isEmpty) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                child: EmptyState(
                  icon: Icons.group_add_outlined,
                  title: 'No friends added yet',
                  message:
                      'Add teammates by email to see them in your friends list.',
                  action: PrimaryButton(
                    label: 'Add a friend',
                    icon: Icons.person_add_alt_1,
                    onPressed: () => _openAddFriendSheet(context),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              itemCount: friends.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final friend = friends[index];
                return _FriendTile(
                  friend: friend,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OtherUserProfileScreen(uid: friend.uid),
                    ),
                  ),
                  onRemove: () => _confirmRemove(context, friend),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAddFriendSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => _AddFriendSheet(currentUser: currentUser),
    );
  }

  Future<void> _confirmRemove(BuildContext context, Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColours.surface,
        title: const Text('Remove friend?'),
        content: Text(
          'Remove ${friend.fullName} from your friends list? You can re-add them later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColours.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmed != true) return;
    final viewModel = context.read<FriendsViewModel>();
    final ok = await viewModel.removeFriend(
      myUid: currentUser.uid,
      friendUid: friend.uid,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Removed ${friend.fullName}.' : viewModel.errorMessage ?? 'Could not remove friend.',
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.onTap,
    required this.onRemove,
  });

  final Friend friend;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final relColor = friend.reliabilityScore >= 75
        ? AppColours.accent
        : friend.reliabilityScore >= 60
            ? AppColours.warning
            : AppColours.error;

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
            fullName: friend.fullName,
            photoUrl: friend.photoUrl,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.fullName,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${friend.position} · ${friend.skillLevel}',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: relColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Rel ${friend.reliabilityScore}',
              style: AppTextStyles.small.copyWith(
                color: relColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(
              Icons.more_vert,
              size: 18,
              color: AppColours.mutedText,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet({required this.currentUser});

  final AppUser currentUser;

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final viewModel = context.read<FriendsViewModel>();
    final friend = await viewModel.addFriendByEmail(
      me: widget.currentUser,
      email: _emailController.text,
    );
    if (!mounted) return;
    if (friend == null) {
      // Surface the underlying error in the sheet.
      setState(() {});
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${friend.fullName} as a friend.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FriendsViewModel>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColours.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text('Add a friend', style: AppTextStyles.h2),
                const SizedBox(height: 6),
                Text(
                  "Enter the email your friend signed up with.",
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.email,
                ),
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    viewModel.errorMessage!,
                    style:
                        AppTextStyles.small.copyWith(color: AppColours.error),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Add friend',
                  icon: Icons.person_add_alt_1,
                  isLoading: viewModel.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
