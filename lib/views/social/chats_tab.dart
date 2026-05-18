import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../models/chat.dart';
import '../../services/friends_service.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../viewmodels/friends_viewmodel.dart';
import 'chat_thread_screen.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();

    return StreamBuilder<List<Chat>>(
      stream: viewModel.myChatsStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColours.accent),
          );
        }
        final chats = (snapshot.data ?? [])
            .where((c) => c.lastMessage.isNotEmpty)
            .toList();
        if (chats.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: EmptyState(
                icon: Icons.forum_outlined,
                title: 'No chats yet',
                message: 'Tap below to start a chat with a friend.',
                action: PrimaryButton(
                  label: 'Start a chat',
                  icon: Icons.edit_outlined,
                  onPressed: () => _openNewChatSheet(context),
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 90),
              itemCount: chats.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 76,
                color: AppColours.line,
              ),
              itemBuilder: (context, index) =>
                  _ChatRow(chat: chats[index], currentUser: currentUser),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton.small(
                heroTag: 'new-chat',
                backgroundColor: AppColours.accent,
                foregroundColor: AppColours.background,
                onPressed: () => _openNewChatSheet(context),
                child: const Icon(Icons.edit_outlined),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openNewChatSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColours.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NewChatSheet(currentUser: currentUser),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat, required this.currentUser});

  final Chat chat;
  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final other = chat.otherParticipant(currentUser.uid);
    final isMine = chat.lastSenderUid == currentUser.uid;
    final unread = chat.hasUnreadFor(currentUser.uid);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatThreadScreen(
            currentUser: currentUser,
            otherUid: other.uid,
            otherName: other.name,
            otherPhotoUrl: other.photoUrl,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            UserAvatar(
              fullName: other.name,
              photoUrl: other.photoUrl,
              radius: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          other.name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(chat.lastMessageAt),
                        style: AppTextStyles.small.copyWith(
                          color: unread
                              ? AppColours.accent
                              : AppColours.mutedText,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isMine
                              ? 'You: ${chat.lastMessage}'
                              : chat.lastMessage,
                          style: AppTextStyles.small.copyWith(
                            color: unread
                                ? AppColours.text
                                : AppColours.mutedText,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColours.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final isToday = time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;
    if (isToday) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${time.day}/${time.month}';
  }
}

class _NewChatSheet extends StatelessWidget {
  const _NewChatSheet({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context) {
    final friendsViewModel = context.watch<FriendsViewModel>();
    final screenHeight = MediaQuery.of(context).size.height;

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
              Text('New chat', style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text(
                'Pick a friend to message.',
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: 14),
              Flexible(
                child: StreamBuilder<List<Friend>>(
                  stream: friendsViewModel.friendsStream(currentUser.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColours.accent,
                          ),
                        ),
                      );
                    }
                    final friends = snapshot.data ?? [];
                    if (friends.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Add friends first to chat with them here.',
                          style: AppTextStyles.bodyMuted,
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: friends.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ChatThreadScreen(
                                  currentUser: currentUser,
                                  otherUid: friend.uid,
                                  otherName: friend.fullName,
                                  otherPhotoUrl: friend.photoUrl,
                                ),
                              ),
                            );
                          },
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
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppColours.accent,
                                  size: 18,
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
            ],
          ),
        ),
      ),
    );
  }
}
