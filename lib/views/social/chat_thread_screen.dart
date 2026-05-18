import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/app_user.dart';
import '../../models/chat.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../profile/other_user_profile_screen.dart';

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.currentUser,
    required this.otherUid,
    required this.otherName,
    this.otherPhotoUrl,
  });

  final AppUser currentUser;
  final String otherUid;
  final String otherName;
  final String? otherPhotoUrl;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();
  late final String _chatId;

  @override
  void initState() {
    super.initState();
    _chatId = Chat.idFor(widget.currentUser.uid, widget.otherUid);
    // Ensure the chat doc exists so the StreamBuilder has something to read.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = context.read<ChatViewModel>();
      // Reuse openChatWith via a minimal AppUser stand-in for the other side.
      await viewModel.openChatWith(
        me: widget.currentUser,
        other: AppUser(
          uid: widget.otherUid,
          fullName: widget.otherName,
          email: '',
          age: 0,
          location: '',
          preferredPosition: 'Any',
          secondaryPosition: 'Any',
          skillLevel: 'Casual',
          favouriteFoot: 'Right',
          bio: '',
          photoUrl: widget.otherPhotoUrl,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      await viewModel.markChatSeen(
        chatId: _chatId,
        uid: widget.currentUser.uid,
      );
    });
  }

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
    final viewModel = context.read<ChatViewModel>();
    await viewModel.sendMessage(
      chatId: _chatId,
      sender: widget.currentUser,
      body: body,
    );
    await viewModel.markChatSeen(
      chatId: _chatId,
      uid: widget.currentUser.uid,
    );
    // Scroll to bottom shortly after the new message lands.
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
    final viewModel = context.watch<ChatViewModel>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => OtherUserProfileScreen(
                uid: widget.otherUid,
                viewer: widget.currentUser,
              ),
            ),
          ),
          child: Row(
            children: [
              UserAvatar(
                fullName: widget.otherName,
                photoUrl: widget.otherPhotoUrl,
                radius: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.otherName,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: viewModel.messagesStream(_chatId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Say hi to ${widget.otherName.split(' ').first}.',
                          style: AppTextStyles.bodyMuted,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderUid == widget.currentUser.uid;
                      return _MessageBubble(message: msg, isMe: isMe);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: AppColours.surface,
                border: Border(top: BorderSide(color: AppColours.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
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
                    onPressed: _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColours.accent,
                      foregroundColor: const Color(0xFF071014),
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: isMe ? AppColours.accent : AppColours.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMe ? 14 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 14),
                ),
                border: Border.all(
                  color: isMe ? AppColours.accent : AppColours.line,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.body,
                    style: AppTextStyles.body.copyWith(
                      color: isMe ? AppColours.background : AppColours.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _time(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? AppColours.background.withValues(alpha: 0.7)
                          : AppColours.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
