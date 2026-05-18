import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/chat.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  /// All chats the current user is a participant of, most recent first.
  Stream<List<Chat>> myChatsStream(String uid) {
    return _chats
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Chat.fromFirestore).toList(),
        );
  }

  Stream<List<ChatMessage>> messagesStream(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(ChatMessage.fromFirestore).toList(),
        );
  }

  /// Resolves (or creates) the 1:1 chat doc between two users, returning
  /// the chat id. Idempotent — the doc id is derived from the sorted
  /// participant uids.
  Future<String> openChatWith({
    required AppUser me,
    required AppUser other,
  }) async {
    final id = Chat.idFor(me.uid, other.uid);
    final ref = _chats.doc(id);
    final existing = await ref.get();
    if (existing.exists) return id;

    final now = DateTime.now();
    final sortedUids = [me.uid, other.uid]..sort();
    final isMeFirst = sortedUids.first == me.uid;
    final chat = Chat(
      id: id,
      participantIds: sortedUids,
      participantNames: isMeFirst
          ? [me.fullName, other.fullName]
          : [other.fullName, me.fullName],
      participantPhotos: isMeFirst
          ? [me.photoUrl, other.photoUrl]
          : [other.photoUrl, me.photoUrl],
      lastMessage: '',
      lastSenderUid: '',
      lastMessageAt: now,
      createdAt: now,
    );
    await ref.set(chat.toMap());
    return id;
  }

  Future<void> markChatSeen({
    required String chatId,
    required String uid,
  }) async {
    await _chats.doc(chatId).set({
      'seenAt': {uid: Timestamp.fromDate(DateTime.now())},
    }, SetOptions(merge: true));
  }

  Future<void> sendMessage({
    required String chatId,
    required AppUser sender,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    final chatRef = _chats.doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderUid': sender.uid,
      'body': trimmed,
      'createdAt': Timestamp.fromDate(now),
    });
    batch.update(chatRef, {
      'lastMessage': trimmed,
      'lastSenderUid': sender.uid,
      'lastMessageAt': Timestamp.fromDate(now),
    });
    await batch.commit();
  }
}
