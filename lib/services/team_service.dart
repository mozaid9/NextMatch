import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/chat.dart';
import '../models/team.dart';

class TeamService {
  TeamService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _teams =>
      _firestore.collection('teams');

  /// Sorted client-side: arrayContains + orderBy needs a composite index,
  /// and a user's team list is small.
  Stream<List<Team>> myTeamsStream(String uid) {
    return _teams
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Team.fromFirestore).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<Team?> teamStream(String teamId) {
    return _teams.doc(teamId).snapshots().map(
          (snapshot) => snapshot.exists ? Team.fromFirestore(snapshot) : null,
        );
  }

  Future<Team> createTeam({
    required AppUser creator,
    required String name,
    required String description,
    String colour = '#21D07A',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final captain = TeamMember(
      uid: creator.uid,
      fullName: creator.fullName,
      photoUrl: creator.photoUrl,
      role: 'captain',
      joinedAt: now,
    );
    final team = Team(
      id: id,
      name: name.trim(),
      description: description.trim(),
      creatorUid: creator.uid,
      memberIds: [creator.uid],
      members: [captain],
      colour: colour,
      createdAt: now,
    );
    await _teams.doc(id).set(team.toMap());
    return team;
  }

  Future<void> addMembers({
    required String teamId,
    required List<AppUser> users,
  }) async {
    if (users.isEmpty) return;
    final now = DateTime.now();
    await _firestore.runTransaction((transaction) async {
      final ref = _teams.doc(teamId);
      final snap = await transaction.get(ref);
      if (!snap.exists) throw Exception('Team not found.');
      final team = Team.fromFirestore(snap);
      final existing = team.memberIds.toSet();
      final newMembers = <TeamMember>[];
      final newIds = <String>[];
      for (final u in users) {
        if (existing.contains(u.uid)) continue;
        newMembers.add(TeamMember(
          uid: u.uid,
          fullName: u.fullName,
          photoUrl: u.photoUrl,
          role: 'member',
          joinedAt: now,
        ));
        newIds.add(u.uid);
      }
      if (newMembers.isEmpty) return;
      final allMembers = [...team.members, ...newMembers];
      transaction.update(ref, {
        'memberIds': [...team.memberIds, ...newIds],
        'members': allMembers.map((m) => m.toMap()).toList(),
      });
    });
  }

  Future<void> leaveTeam({
    required String teamId,
    required String uid,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final ref = _teams.doc(teamId);
      final snap = await transaction.get(ref);
      if (!snap.exists) return;
      final team = Team.fromFirestore(snap);
      final remainingMembers =
          team.members.where((m) => m.uid != uid).toList();
      final remainingIds = team.memberIds.where((id) => id != uid).toList();

      if (remainingMembers.isEmpty) {
        // Last member out → delete the team.
        transaction.delete(ref);
        return;
      }

      // If the captain leaves, promote the oldest remaining member.
      if (team.memberFor(uid)?.isCaptain == true) {
        remainingMembers.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
        final newCaptain = TeamMember(
          uid: remainingMembers.first.uid,
          fullName: remainingMembers.first.fullName,
          photoUrl: remainingMembers.first.photoUrl,
          role: 'captain',
          joinedAt: remainingMembers.first.joinedAt,
        );
        remainingMembers[0] = newCaptain;
      }

      transaction.update(ref, {
        'memberIds': remainingIds,
        'members': remainingMembers.map((m) => m.toMap()).toList(),
      });
    });
  }

  // Team chat is stored under teams/{teamId}/messages/...
  // Reuses the ChatMessage model.
  Stream<List<ChatMessage>> messagesStream(String teamId) {
    return _teams
        .doc(teamId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(ChatMessage.fromFirestore).toList());
  }

  Future<void> sendMessage({
    required String teamId,
    required AppUser sender,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    await _teams.doc(teamId).collection('messages').add({
      'senderUid': sender.uid,
      'senderName': sender.fullName,
      'senderPhotoUrl': sender.photoUrl,
      'body': trimmed,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
