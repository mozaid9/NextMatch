import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel(this._chatService);

  final ChatService _chatService;

  bool isLoading = false;
  String? errorMessage;

  Stream<List<Chat>> myChatsStream(String uid) =>
      _chatService.myChatsStream(uid);

  Stream<List<ChatMessage>> messagesStream(String chatId) =>
      _chatService.messagesStream(chatId);

  Future<String?> openChatWith({
    required AppUser me,
    required AppUser other,
  }) async {
    try {
      return await _chatService.openChatWith(me: me, other: other);
    } catch (error) {
      errorMessage = 'Could not start chat.';
      notifyListeners();
      return null;
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required AppUser sender,
    required String body,
  }) async {
    try {
      await _chatService.sendMessage(
        chatId: chatId,
        sender: sender,
        body: body,
      );
    } catch (error) {
      errorMessage = 'Could not send message.';
      notifyListeners();
    }
  }
}
