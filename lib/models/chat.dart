import 'package:cloud_firestore/cloud_firestore.dart';

/// A 1:1 direct-message conversation between two users. The doc id is a
/// deterministic composite of the two uids (sorted), so creating a chat
/// is idempotent.
class Chat {
  const Chat({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantPhotos,
    required this.lastMessage,
    required this.lastSenderUid,
    required this.lastMessageAt,
    required this.createdAt,
  });

  final String id;
  final List<String> participantIds;
  final List<String> participantNames;
  final List<String?> participantPhotos;
  final String lastMessage;
  final String lastSenderUid;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  /// Convenience — given my uid, returns the other participant's details.
  ({String uid, String name, String? photoUrl}) otherParticipant(String myUid) {
    final idx = participantIds.indexOf(myUid);
    final otherIdx = idx == 0 ? 1 : 0;
    return (
      uid: participantIds[otherIdx],
      name: participantNames[otherIdx],
      photoUrl: participantPhotos.length > otherIdx
          ? participantPhotos[otherIdx]
          : null,
    );
  }

  /// Sorts two uids alphabetically and joins with `_` to form a stable
  /// chat document id.
  static String idFor(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  factory Chat.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return Chat(
      id: document.id,
      participantIds:
          (data['participantIds'] as List?)?.cast<String>() ?? const [],
      participantNames:
          (data['participantNames'] as List?)?.cast<String>() ?? const [],
      participantPhotos: (data['participantPhotos'] as List?)
              ?.map((v) => v as String?)
              .toList() ??
          const [],
      lastMessage: data['lastMessage'] as String? ?? '',
      lastSenderUid: data['lastSenderUid'] as String? ?? '',
      lastMessageAt: _readDate(data['lastMessageAt']),
      createdAt: _readDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'participantIds': participantIds,
        'participantNames': participantNames,
        'participantPhotos': participantPhotos,
        'lastMessage': lastMessage,
        'lastSenderUid': lastSenderUid,
        'lastMessageAt': Timestamp.fromDate(lastMessageAt),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.body,
    required this.createdAt,
    this.senderName,
    this.senderPhotoUrl,
  });

  final String id;
  final String senderUid;
  final String body;
  final DateTime createdAt;
  /// Denormalised sender info — only populated for group/team chats where
  /// the thread needs to render the sender's name per message.
  final String? senderName;
  final String? senderPhotoUrl;

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: document.id,
      senderUid: data['senderUid'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: Chat._readDate(data['createdAt']),
      senderName: data['senderName'] as String?,
      senderPhotoUrl: data['senderPhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderUid': senderUid,
        'body': body,
        'createdAt': Timestamp.fromDate(createdAt),
        if (senderName != null) 'senderName': senderName,
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
      };
}
