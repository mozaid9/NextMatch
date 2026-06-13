import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../models/chat.dart';
import '../../models/team.dart';
import '../../services/friends_service.dart';
import '../../viewmodels/friends_viewmodel.dart';
import '../../viewmodels/team_viewmodel.dart';

class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({
    super.key,
    required this.teamId,
    required this.currentUser,
  });

  final String teamId;
  final AppUser currentUser;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _bodyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    _bodyController.clear();
    await context.read<TeamViewModel>().sendMessage(
          teamId: widget.teamId,
          sender: widget.currentUser,
          body: body,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamViewModel = context.watch<TeamViewModel>();

    return Scaffold(
      body: StreamBuilder<Team?>(
        stream: teamViewModel.teamStream(widget.teamId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColours.accent),
            );
          }
          final team = snapshot.data;
          if (team == null) {
            return const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: EmptyState(
                  icon: Icons.shield_outlined,
                  title: 'Team not found',
                  message: 'This team may have been disbanded.',
                ),
              ),
            );
          }

          final me = team.memberFor(widget.currentUser.uid);
          final isCaptain = me?.isCaptain ?? false;

          return SafeArea(
            child: Column(
              children: [
                _TeamHeader(team: team),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      _MembersSection(
                        team: team,
                        canAdd: isCaptain,
                        onAddTap: () => _openAddMembersSheet(context, team),
                      ),
                      const SizedBox(height: 18),
                      Text('Team chat', style: AppTextStyles.h3),
                      const SizedBox(height: 10),
                      _TeamChat(
                        teamId: widget.teamId,
                        currentUser: widget.currentUser,
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => _confirmLeave(context, team),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColours.error,
                          side: const BorderSide(color: AppColours.error),
                        ),
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Leave team'),
                      ),
                    ],
                  ),
                ),
                _ChatComposer(
                  controller: _bodyController,
                  onSend: _send,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAddMembersSheet(
    BuildContext context,
    Team team,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          _AddMembersSheet(team: team, currentUser: widget.currentUser),
    );
  }

  Future<void> _confirmLeave(BuildContext context, Team team) async {
    final confirmed = await showAppConfirmSheet(
      context: context,
      title: 'Leave team?',
      message:
          'You\'ll need to be added back by the captain to rejoin. If you\'re the last member, the team is deleted.',
      confirmLabel: 'Leave',
      confirmIcon: Icons.logout,
      isDestructive: true,
    );
    if (!context.mounted || confirmed != true) return;
    final viewModel = context.read<TeamViewModel>();
    final ok = await viewModel.leaveTeam(
      teamId: team.id,
      uid: widget.currentUser.uid,
    );
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Left ${team.name}.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Could not leave team.'),
        ),
      );
    }
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team});

  final Team team;

  Color _teamColour() {
    final hex = team.colour.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final colour = _teamColour();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colour.withValues(alpha: 0.22),
            colour.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: AppColours.line)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colour),
            ),
            child: Icon(Icons.shield, color: colour, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name, style: AppTextStyles.h2),
                if (team.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    team.description,
                    style: AppTextStyles.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.team,
    required this.canAdd,
    required this.onAddTap,
  });

  final Team team;
  final bool canAdd;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Squad · ${team.members.length}', style: AppTextStyles.h3),
            const Spacer(),
            if (canAdd)
              TextButton.icon(
                onPressed: onAddTap,
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: team.members
              .map((member) => _MemberChip(member: member))
              .toList(),
        ),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          UserAvatar(
            fullName: member.fullName,
            photoUrl: member.photoUrl,
            radius: 22,
          ),
          const SizedBox(height: 6),
          Text(
            member.fullName.split(' ').first,
            style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (member.isCaptain)
            Text(
              'Captain',
              style: AppTextStyles.small.copyWith(
                color: AppColours.accent,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamChat extends StatelessWidget {
  const _TeamChat({required this.teamId, required this.currentUser});

  final String teamId;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TeamViewModel>();
    return StreamBuilder<List<ChatMessage>>(
      stream: viewModel.messagesStream(teamId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Be the first to chat with the squad.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          );
        }
        return Column(
          children: messages.map((msg) {
            final isMe = msg.senderUid == currentUser.uid;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe) ...[
                    UserAvatar(
                      fullName: msg.senderName ?? '?',
                      photoUrl: msg.senderPhotoUrl,
                      radius: 14,
                    ),
                    const SizedBox(width: 8),
                  ],
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? AppColours.accent : AppColours.cardAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMe
                              ? AppColours.accent
                              : AppColours.line,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe && msg.senderName != null)
                            Text(
                              msg.senderName!,
                              style: AppTextStyles.small.copyWith(
                                color: AppColours.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          Text(
                            msg.body,
                            style: AppTextStyles.body.copyWith(
                              color: isMe
                                  ? AppColours.background
                                  : AppColours.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColours.surface,
        border: Border(top: BorderSide(color: AppColours.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              style: AppTextStyles.body,
              decoration: const InputDecoration(
                hintText: 'Message the squad…',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            style: IconButton.styleFrom(
              backgroundColor: AppColours.accent,
              foregroundColor: const Color(0xFF071014),
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(Icons.send, size: 18),
          ),
        ],
      ),
    );
  }
}

class _AddMembersSheet extends StatefulWidget {
  const _AddMembersSheet({required this.team, required this.currentUser});

  final Team team;
  final AppUser currentUser;

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final Set<String> _selectedUids = <String>{};

  @override
  Widget build(BuildContext context) {
    final friendsViewModel = context.watch<FriendsViewModel>();
    final teamViewModel = context.watch<TeamViewModel>();
    final screenHeight = MediaQuery.of(context).size.height;

    final existing = widget.team.memberIds.toSet();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.8),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
              Text('Add members', style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text(
                'Pick friends to invite to ${widget.team.name}.',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: 14),
              Flexible(
                child: StreamBuilder<List<Friend>>(
                  stream:
                      friendsViewModel.friendsStream(widget.currentUser.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColours.accent,
                          ),
                        ),
                      );
                    }
                    final friends = snapshot.data ?? [];
                    final addable = friends
                        .where((f) => !existing.contains(f.uid))
                        .toList();
                    if (addable.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          friends.isEmpty
                              ? "You haven't added any friends yet. Friends you add will show up here."
                              : 'All your friends are already on this team.',
                          style: AppTextStyles.bodyMuted,
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: addable.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final friend = addable[index];
                        final selected = _selectedUids.contains(friend.uid);
                        return InkWell(
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedUids.remove(friend.uid);
                            } else {
                              _selectedUids.add(friend.uid);
                            }
                          }),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColours.accent.withValues(alpha: 0.08)
                                  : AppColours.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? AppColours.accent
                                    : AppColours.line,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                UserAvatar(
                                  fullName: friend.fullName,
                                  photoUrl: friend.photoUrl,
                                  radius: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    friend.fullName,
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: selected
                                      ? AppColours.accent
                                      : AppColours.mutedText,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: _selectedUids.isEmpty
                    ? 'Pick someone'
                    : 'Add ${_selectedUids.length} player${_selectedUids.length == 1 ? "" : "s"}',
                icon: Icons.person_add_alt_1,
                isLoading: teamViewModel.isLoading,
                onPressed: _selectedUids.isEmpty
                    ? null
                    : () async {
                        // Resolve full AppUser objects for each selected uid.
                        final users = <AppUser>[];
                        for (final uid in _selectedUids) {
                          final u = await friendsViewModel.getUserById(uid);
                          if (u != null) users.add(u);
                        }
                        if (!context.mounted) return;
                        final ok = await teamViewModel.addMembers(
                          teamId: widget.team.id,
                          users: users,
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Added to ${widget.team.name}.'
                                  : teamViewModel.errorMessage ??
                                      'Could not add members.',
                            ),
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
