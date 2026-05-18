import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../models/chat.dart';
import '../../viewmodels/chat_viewmodel.dart';
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
            // Hide chats that have no messages yet (created on first open).
            .where((c) => c.lastMessage.isNotEmpty)
            .toList();
        if (chats.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: EmptyState(
                icon: Icons.forum_outlined,
                title: 'No chats yet',
                message:
                    'Open a friend\'s profile and tap Message to start a direct chat.',
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: chats.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            indent: 76,
            color: AppColours.line,
          ),
          itemBuilder: (context, index) {
            final chat = chats[index];
            final other = chat.otherParticipant(currentUser.uid);
            final isMine = chat.lastSenderUid == currentUser.uid;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                style: AppTextStyles.small,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isMine
                                ? 'You: ${chat.lastMessage}'
                                : chat.lastMessage,
                            style: AppTextStyles.small,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
