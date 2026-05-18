import 'package:cloud_firestore/cloud_firestore.dart';

class TeamMember {
  const TeamMember({
    required this.uid,
    required this.fullName,
    required this.photoUrl,
    required this.role,
    required this.joinedAt,
  });

  final String uid;
  final String fullName;
  final String? photoUrl;
  /// "captain" or "member"
  final String role;
  final DateTime joinedAt;

  bool get isCaptain => role == 'captain';

  factory TeamMember.fromMap(Map<String, dynamic> data) => TeamMember(
        uid: data['uid'] as String? ?? '',
        fullName: data['fullName'] as String? ?? '',
        photoUrl: data['photoUrl'] as String?,
        role: data['role'] as String? ?? 'member',
        joinedAt: Team._readDate(data['joinedAt']),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fullName': fullName,
        'photoUrl': photoUrl,
        'role': role,
        'joinedAt': Timestamp.fromDate(joinedAt),
      };
}

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorUid,
    required this.memberIds,
    required this.members,
    required this.colour,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String creatorUid;
  /// Mirror of members.keys, exposed as an array for arrayContains queries.
  final List<String> memberIds;
  final List<TeamMember> members;
  /// Hex colour string like "#21D07A". Used to tint the team header.
  final String colour;
  final DateTime createdAt;

  TeamMember? memberFor(String uid) {
    for (final m in members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  bool get isCaptainOnly => members.length == 1;

  factory Team.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final membersRaw = data['members'] as List? ?? const [];
    final members = membersRaw
        .map((m) => TeamMember.fromMap(m as Map<String, dynamic>))
        .toList();
    return Team(
      id: document.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      creatorUid: data['creatorUid'] as String? ?? '',
      memberIds:
          (data['memberIds'] as List?)?.cast<String>() ?? const [],
      members: members,
      colour: data['colour'] as String? ?? '#21D07A',
      createdAt: _readDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'creatorUid': creatorUid,
        'memberIds': memberIds,
        'members': members.map((m) => m.toMap()).toList(),
        'colour': colour,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
