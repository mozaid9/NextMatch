import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../services/friends_service.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../profile/other_user_profile_screen.dart';

/// Standalone screen wrapper used when Friends is pushed as a route
/// (e.g. from the Profile screen's old "Friends" button).
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: FriendsTab(currentUser: currentUser),
    );
  }
}

/// The reusable body of the Friends area — search, suggestions, list.
/// Designed to live inside a TabBarView (no Scaffold / AppBar of its own).
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<AppUser> _searchResults = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final trimmed = value.trim();
    setState(() => _query = trimmed);
    _debounce?.cancel();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await context
          .read<FriendsViewModel>()
          .searchUsersByName(me: widget.currentUser, query: trimmed);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  Future<void> _addUser(AppUser user) async {
    final viewModel = context.read<FriendsViewModel>();
    final ok = await viewModel.addFriendByUser(
      me: widget.currentUser,
      friend: user,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Added ${user.fullName} as a friend.'
              : viewModel.errorMessage ?? 'Could not add friend.',
        ),
      ),
    );
    if (ok) {
      // Remove from search results / suggestions so it disappears.
      setState(() {
        _searchResults =
            _searchResults.where((u) => u.uid != user.uid).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsViewModel = context.watch<FriendsViewModel>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      children: [
        _SearchField(
          controller: _searchController,
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 18),
        if (_query.isEmpty) ...[
          _SuggestionsSection(
            currentUser: widget.currentUser,
            onAdd: _addUser,
          ),
          const SizedBox(height: 18),
          _FriendsListSection(currentUser: widget.currentUser),
        ] else
          _SearchResultsSection(
            results: _searchResults,
            loading: _searching,
            onAdd: _addUser,
            friendsViewModel: friendsViewModel,
          ),
        const SizedBox(height: 18),
        // Invite by email available inline since there's no AppBar here.
        OutlinedButton.icon(
          onPressed: () => _openAddByEmailSheet(context),
          icon: const Icon(Icons.alternate_email, size: 16),
          label: const Text('Invite by email'),
        ),
      ],
    );
  }

  Future<void> _openAddByEmailSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddFriendSheet(currentUser: widget.currentUser),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColours.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColours.line),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Search players by name',
          prefixIcon: const Icon(Icons.search, color: AppColours.mutedText),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _SuggestionsSection extends StatelessWidget {
  const _SuggestionsSection({
    required this.currentUser,
    required this.onAdd,
  });

  final AppUser currentUser;
  final ValueChanged<AppUser> onAdd;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<FriendsViewModel>();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: viewModel.suggestedFriends(currentUser.uid),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColours.accent, size: 18),
                const SizedBox(width: 8),
                Text('People you may know', style: AppTextStyles.h2),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Players you've shared matches with.",
              style: AppTextStyles.small,
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SuggestionTile(
                  data: item,
                  onAddTap: () async {
                    final uid = item['userId'] as String;
                    final friend = await context
                        .read<FriendsViewModel>()
                        .getUserById(uid);
                    if (friend != null) onAdd(friend);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.data, required this.onAddTap});

  final Map<String, dynamic> data;
  final Future<void> Function() onAddTap;

  @override
  Widget build(BuildContext context) {
    final name = data['fullName'] as String? ?? '';
    final count = data['count'] as int? ?? 0;
    final uid = data['userId'] as String? ?? '';

    return InkWell(
      onTap: uid.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OtherUserProfileScreen(uid: uid),
                ),
              ),
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
              fullName: name,
              photoUrl: data['photoUrl'] as String?,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 1
                        ? 'Played 1 match together'
                        : 'Played $count matches together',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: onAddTap,
                icon: const Icon(Icons.person_add_alt_1, size: 14),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColours.accent,
                  foregroundColor: AppColours.background,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({
    required this.results,
    required this.loading,
    required this.onAdd,
    required this.friendsViewModel,
  });

  final List<AppUser> results;
  final bool loading;
  final ValueChanged<AppUser> onAdd;
  final FriendsViewModel friendsViewModel;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: AppColours.accent),
        ),
      );
    }
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: EmptyState(
          icon: Icons.person_search_outlined,
          title: 'No players found',
          message: 'Try a different name, or invite them by email.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Search results', style: AppTextStyles.h2),
        const SizedBox(height: 10),
        ...results.map(
          (user) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SearchResultTile(
              user: user,
              onAdd: () => onAdd(user),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.user, required this.onAdd});

  final AppUser user;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OtherUserProfileScreen(uid: user.uid),
        ),
      ),
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
              fullName: user.fullName,
              photoUrl: user.photoUrl,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${user.preferredPosition} · ${user.skillLevel}',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt_1, size: 14),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColours.accent,
                  foregroundColor: AppColours.background,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsListSection extends StatelessWidget {
  const _FriendsListSection({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final friendsViewModel = context.watch<FriendsViewModel>();

    return StreamBuilder<List<Friend>>(
      stream: friendsViewModel.friendsStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColours.accent),
            ),
          );
        }

        final friends = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              friends.isEmpty
                  ? 'Your friends'
                  : 'Your friends · ${friends.length}',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 10),
            if (friends.isEmpty)
              EmptyState(
                icon: Icons.group_add_outlined,
                title: 'No friends yet',
                message:
                    'Search above to find players, or invite a teammate by email.',
              )
            else
              ...friends.map(
                (friend) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FriendTile(
                    friend: friend,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OtherUserProfileScreen(uid: friend.uid),
                      ),
                    ),
                    onRemove: () => _confirmRemove(context, friend, currentUser),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    Friend friend,
    AppUser me,
  ) async {
    final confirmed = await showAppConfirmSheet(
      context: context,
      title: 'Remove friend?',
      message:
          'Remove ${friend.fullName} from your friends list? You can re-add them later.',
      confirmLabel: 'Remove',
      confirmIcon: Icons.person_remove_alt_1_outlined,
      isDestructive: true,
    );

    if (!context.mounted || confirmed != true) return;
    final viewModel = context.read<FriendsViewModel>();
    final ok = await viewModel.removeFriend(
      myUid: me.uid,
      friendUid: friend.uid,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Removed ${friend.fullName}.'
              : viewModel.errorMessage ?? 'Could not remove friend.',
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
                Text('Invite by email', style: AppTextStyles.h2),
                const SizedBox(height: 6),
                Text(
                  "Useful when you can't find someone by name — paste the "
                  'email they signed up with.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: 18),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'name@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
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
                  label: 'Send invite',
                  icon: Icons.send_outlined,
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
