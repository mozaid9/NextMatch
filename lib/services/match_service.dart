import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/football_match.dart';
import '../models/match_comment.dart';
import '../models/match_participant.dart';
import '../models/waitlist_entry.dart';
import 'reliability_service.dart';

class JoinRequestResult {
  const JoinRequestResult({
    required this.requiresApproval,
    required this.canContinueToPayment,
    required this.message,
  });

  final bool requiresApproval;
  final bool canContinueToPayment;
  final String message;
}

class MatchService {
  MatchService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _matches =>
      _firestore.collection('matches');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<List<FootballMatch>> openMatchesStream() {
    // Security rules only permit listing public matches, so the query must
    // constrain visibility server-side. Sorting stays client-side to avoid
    // a composite index.
    return _matches.where('visibility', isEqualTo: 'Public').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map(FootballMatch.fromFirestore)
          .where(
            (match) =>
                match.status != 'Full' &&
                match.status != 'Completed' &&
                match.status != 'Cancelled' &&
                match.startDateTime.isAfter(
                  DateTime.now().subtract(const Duration(hours: 2)),
                ),
          )
          .toList()
        ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    });
  }

  Stream<FootballMatch?> matchStream(String matchId) {
    return _matches.doc(matchId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return FootballMatch.fromFirestore(snapshot);
    });
  }

  Future<FootballMatch?> getMatch(String matchId) async {
    final snapshot = await _matches.doc(matchId).get();
    if (!snapshot.exists) return null;
    return FootballMatch.fromFirestore(snapshot);
  }

  Stream<List<MatchParticipant>> participantsStream(String matchId) {
    return _matches
        .doc(matchId)
        .collection('participants')
        .orderBy('joinedAt')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(MatchParticipant.fromFirestore).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> joinedMatchSummariesStream(String uid) {
    return _users
        .doc(uid)
        .collection('joinedMatches')
        .orderBy('matchDateTime')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<FootballMatch>> organisedMatchesStream(String uid) {
    return _matches.where('organiserId', isEqualTo: uid).snapshots().map((
      snapshot,
    ) {
      final matches = snapshot.docs.map(FootballMatch.fromFirestore).toList();
      matches.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      return matches;
    });
  }

  /// Returns up to 6 players the user has most frequently played with,
  /// sorted by number of shared matches descending.
  Future<List<Map<String, dynamic>>> getFrequentCoPlayers(String uid) async {
    final joinedDocs = await _users
        .doc(uid)
        .collection('joinedMatches')
        .limit(30)
        .get();

    final matchIds = joinedDocs.docs
        .map((d) => d.data()['matchId'] as String?)
        .whereType<String>()
        .toList();

    if (matchIds.isEmpty) return [];

    final Map<String, Map<String, dynamic>> coMap = {};
    for (final matchId in matchIds) {
      final snap = await _matches.doc(matchId).collection('participants').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final playerId = data['userId'] as String? ?? doc.id;
        if (playerId == uid) continue;
        final name = data['fullName'] as String? ?? '';
        if (name.isEmpty) continue;
        final photoUrl = data['photoUrl'] as String?;
        if (coMap.containsKey(playerId)) {
          coMap[playerId]!['count'] = (coMap[playerId]!['count'] as int) + 1;
          // Keep the latest non-null photoUrl
          if (photoUrl != null && photoUrl.isNotEmpty) {
            coMap[playerId]!['photoUrl'] = photoUrl;
          }
        } else {
          coMap[playerId] = {
            'userId': playerId,
            'fullName': name,
            'photoUrl': photoUrl,
            'count': 1,
          };
        }
      }
    }

    final sorted = coMap.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return sorted.take(6).toList();
  }

  Future<String> createMatch(FootballMatch match) async {
    final docRef = _matches.doc();
    final now = DateTime.now();
    final initialStatus =
        match.status == 'Completed' || match.status == 'Cancelled'
        ? match.status
        : FootballMatch.statusForCount(
            match.joinedPlayerCount,
            match.totalPlayersNeeded,
          );
    final newMatch = match.copyWith(
      id: docRef.id,
      status: initialStatus,
      endDateTime: match.startDateTime.add(
        Duration(minutes: match.durationMinutes),
      ),
      isRated: false,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(newMatch.toMap());
    return docRef.id;
  }

  Future<JoinRequestResult> requestToJoinMatch({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    final matchRef = _matches.doc(match.id);
    final participantRef = matchRef.collection('participants').doc(user.uid);
    final userJoinedRef = _users
        .doc(user.uid)
        .collection('joinedMatches')
        .doc(match.id);

    return _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchRef);
      if (!matchSnapshot.exists) throw Exception('Match no longer exists.');
      final latestMatch = FootballMatch.fromFirestore(matchSnapshot);

      if (latestMatch.isFull) throw Exception('This match is already full.');
      if (latestMatch.isCompleted || latestMatch.isCancelled) {
        throw Exception('This match is no longer open.');
      }

      final existingParticipant = await transaction.get(participantRef);
      if (existingParticipant.exists) {
        final participant = MatchParticipant.fromFirestore(existingParticipant);
        if (participant.isPendingPayment) {
          return const JoinRequestResult(
            requiresApproval: false,
            canContinueToPayment: false,
            message:
                'You have joined this match. Pay when ready to secure your spot.',
          );
        }
        if (participant.isPendingApproval && participant.organiserApproved) {
          return const JoinRequestResult(
            requiresApproval: false,
            canContinueToPayment: true,
            message: 'Approved. Complete payment to secure your spot.',
          );
        }
        if (participant.isPendingApproval) {
          return const JoinRequestResult(
            requiresApproval: true,
            canContinueToPayment: false,
            message: 'Your request is still waiting for organiser approval.',
          );
        }
        throw Exception('You already have a record for this match.');
      }

      final isPrivateMatch = latestMatch.visibility != 'Public';
      final requiresApproval =
          isPrivateMatch ||
          latestMatch.requiresApprovalForLowReliability &&
              ReliabilityService.isLowReliability(
                user.reliabilityScore,
                latestMatch.minimumReliabilityRequired,
              );

      final now = DateTime.now();

      if (!requiresApproval && latestMatch.isSplitPayment) {
        final participant = MatchParticipant(
          userId: user.uid,
          fullName: user.fullName,
          position: position,
          skillLevel: user.skillLevel,
          abilityRatingAtJoin: user.abilityRating,
          reliabilityScoreAtJoin: user.reliabilityScore,
          paymentStatus: 'PendingPayment',
          joinedAt: now,
          amountPaid: 0,
          amountOwed: 0,
          attendanceStatus: 'PendingPayment',
          organiserApproved: true,
          requiresApproval: false,
          paymentDeadline: now.add(const Duration(hours: 24)),
          photoUrl: user.photoUrl,
        );

        transaction.set(participantRef, participant.toMap());
        transaction.set(userJoinedRef, {
          'matchId': latestMatch.id,
          'joinedAt': Timestamp.fromDate(now),
          'paymentStatus': 'PendingPayment',
          'attendanceStatus': 'PendingPayment',
          'position': position,
          'matchDateTime': Timestamp.fromDate(latestMatch.startDateTime),
          'amountOwed': 0,
          'requiresApproval': false,
          'organiserApproved': true,
          'paymentDeadline': Timestamp.fromDate(
            now.add(const Duration(hours: 24)),
          ),
        });

        return const JoinRequestResult(
          requiresApproval: false,
          canContinueToPayment: false,
          message:
              'You have joined this match. Pay when ready to secure your spot.',
        );
      }

      if (!requiresApproval) {
        return const JoinRequestResult(
          requiresApproval: false,
          canContinueToPayment: false,
          message: 'Join request ready.',
        );
      }

      final participant = MatchParticipant(
        userId: user.uid,
        fullName: user.fullName,
        position: position,
        skillLevel: user.skillLevel,
        abilityRatingAtJoin: user.abilityRating,
        reliabilityScoreAtJoin: user.reliabilityScore,
        paymentStatus: 'PendingApproval',
        joinedAt: now,
        amountPaid: 0,
        amountOwed: 0,
        attendanceStatus: 'PendingApproval',
        organiserApproved: false,
        requiresApproval: true,
        photoUrl: user.photoUrl,
      );

      transaction.set(participantRef, participant.toMap());
      transaction.set(userJoinedRef, {
        'matchId': latestMatch.id,
        'joinedAt': Timestamp.fromDate(now),
        'paymentStatus': 'PendingApproval',
        'attendanceStatus': 'PendingApproval',
        'position': position,
        'matchDateTime': Timestamp.fromDate(latestMatch.startDateTime),
        'amountOwed': 0,
        'requiresApproval': true,
        'organiserApproved': false,
      });

      return const JoinRequestResult(
        requiresApproval: true,
        canContinueToPayment: false,
        message:
            'Your request has been sent to the organiser. You can pay once they approve you.',
      );
    });
  }

  Future<void> freeJoinMatch({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    final approval = await requestToJoinMatch(
      match: match,
      user: user,
      position: position,
    );
    if (approval.requiresApproval) {
      throw Exception(approval.message);
    }

    final matchRef = _matches.doc(match.id);
    final participantRef = matchRef.collection('participants').doc(user.uid);
    final userJoinedRef = _users
        .doc(user.uid)
        .collection('joinedMatches')
        .doc(match.id);

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchRef);
      if (!matchSnapshot.exists) throw Exception('Match no longer exists.');

      final latestMatch = FootballMatch.fromFirestore(matchSnapshot);
      if (latestMatch.isFull) throw Exception('This match is already full.');
      if (latestMatch.isCompleted || latestMatch.isCancelled) {
        throw Exception('This match is no longer open.');
      }

      final existingParticipant = await transaction.get(participantRef);
      if (existingParticipant.exists) {
        final participant = MatchParticipant.fromFirestore(existingParticipant);
        if (!participant.isPendingApproval) {
          throw Exception('You are already in this match.');
        }
      }

      final joinedAt = DateTime.now();
      final newCount = latestMatch.joinedPlayerCount + 1;
      final newStatus = FootballMatch.statusForCount(
        newCount,
        latestMatch.totalPlayersNeeded,
      );

      final participant = MatchParticipant(
        userId: user.uid,
        fullName: user.fullName,
        position: position,
        skillLevel: user.skillLevel,
        abilityRatingAtJoin: user.abilityRating,
        reliabilityScoreAtJoin: user.reliabilityScore,
        paymentStatus: 'Owed',
        joinedAt: joinedAt,
        amountPaid: 0,
        amountOwed: latestMatch.pricePerPlayer,
        attendanceStatus: 'Joined',
        organiserApproved: true,
        requiresApproval: false,
        photoUrl: user.photoUrl,
      );

      transaction.set(
        participantRef,
        participant.toMap(),
        SetOptions(merge: true),
      );
      transaction.set(userJoinedRef, {
        'matchId': latestMatch.id,
        'joinedAt': Timestamp.fromDate(joinedAt),
        'paymentStatus': 'Owed',
        'attendanceStatus': 'Joined',
        'position': position,
        'matchDateTime': Timestamp.fromDate(latestMatch.startDateTime),
        'amountOwed': latestMatch.pricePerPlayer,
        'requiresApproval': false,
        'organiserApproved': true,
      }, SetOptions(merge: true));
      transaction.update(matchRef, {
        'joinedPlayerCount': newCount,
        'status': newStatus,
        'updatedAt': Timestamp.fromDate(joinedAt),
      });
    });
  }

  Future<void> approveParticipant({
    required String matchId,
    required String userId,
  }) async {
    final matchRef = _matches.doc(matchId);
    final participantRef = matchRef.collection('participants').doc(userId);
    final userJoinedRef = _users
        .doc(userId)
        .collection('joinedMatches')
        .doc(matchId);

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchRef);
      final participantSnapshot = await transaction.get(participantRef);
      if (!matchSnapshot.exists || !participantSnapshot.exists) {
        throw Exception('Approval request not found.');
      }

      final match = FootballMatch.fromFirestore(matchSnapshot);
      final participant = MatchParticipant.fromFirestore(participantSnapshot);
      if (!participant.isPendingApproval) {
        throw Exception('This player is not pending approval.');
      }

      final now = DateTime.now();
      final update = <String, dynamic>{
        'organiserApproved': true,
        'requiresApproval': false,
        'approvedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      if (match.isSplitPayment) {
        update['paymentStatus'] = 'ApprovedPendingPayment';
        update['attendanceStatus'] = 'PendingPayment';
        update['paymentDeadline'] = Timestamp.fromDate(
          now.add(const Duration(hours: 24)),
        );
        transaction.update(participantRef, update);
        transaction.set(userJoinedRef, {
          'paymentStatus': 'ApprovedPendingPayment',
          'attendanceStatus': 'PendingPayment',
          'organiserApproved': true,
          'requiresApproval': false,
          'approvedAt': Timestamp.fromDate(now),
          'paymentDeadline': Timestamp.fromDate(
            now.add(const Duration(hours: 24)),
          ),
        }, SetOptions(merge: true));
        return;
      }

      if (match.isFull) throw Exception('This match is already full.');
      final newCount = match.joinedPlayerCount + 1;
      update.addAll({
        'attendanceStatus': 'Joined',
        'paymentStatus': 'Owed',
        'amountOwed': match.pricePerPlayer,
      });
      transaction.update(participantRef, update);
      transaction.set(userJoinedRef, {
        'paymentStatus': 'Owed',
        'attendanceStatus': 'Joined',
        'amountOwed': match.pricePerPlayer,
        'organiserApproved': true,
        'requiresApproval': false,
        'approvedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      transaction.update(matchRef, {
        'joinedPlayerCount': newCount,
        'status': FootballMatch.statusForCount(
          newCount,
          match.totalPlayersNeeded,
        ),
        'updatedAt': Timestamp.fromDate(now),
      });
    });
  }

  Future<void> rejectParticipant({
    required String matchId,
    required String userId,
  }) async {
    final matchRef = _matches.doc(matchId);
    final participantRef = matchRef.collection('participants').doc(userId);
    final userJoinedRef = _users
        .doc(userId)
        .collection('joinedMatches')
        .doc(matchId);
    final now = DateTime.now();

    final batch = _firestore.batch();
    batch.set(participantRef, {
      'attendanceStatus': 'Rejected',
      'organiserApproved': false,
      'requiresApproval': false,
      'rejectedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
    batch.set(userJoinedRef, {
      'attendanceStatus': 'Rejected',
      'organiserApproved': false,
      'requiresApproval': false,
      'rejectedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> withdrawFromMatch({
    required String matchId,
    required String userId,
    String? reason,
  }) async {
    final matchRef = _matches.doc(matchId);
    final participantRef = matchRef.collection('participants').doc(userId);
    final userRef = _users.doc(userId);
    final userJoinedRef = userRef.collection('joinedMatches').doc(matchId);

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchRef);
      final participantSnapshot = await transaction.get(participantRef);
      if (!matchSnapshot.exists || !participantSnapshot.exists) {
        throw Exception('Match place not found.');
      }

      final match = FootballMatch.fromFirestore(matchSnapshot);
      final participant = MatchParticipant.fromFirestore(participantSnapshot);
      if (match.hasStarted || match.isCompleted || match.isCancelled) {
        throw Exception('You cannot withdraw after kick-off.');
      }
      if (!participant.canWithdraw) {
        throw Exception('This place cannot be withdrawn.');
      }

      final now = DateTime.now();
      // The reliability penalty tier is recomputed server-side from kick-off
      // timing (onParticipantReputation). The client only sets the label for
      // the UI; it grants nothing, so the backend never trusts it.
      final penalty = participant.hasConfirmedSlot
          ? ReliabilityService.calculateWithdrawalPenalty(
              match.startDateTime,
              now,
            )
          : 0;
      final isLate = penalty <= ReliabilityService.mediumCancellationPenalty;
      final attendanceStatus = isLate ? 'LateCancelled' : 'Cancelled';
      final confirmedSlot = participant.hasConfirmedSlot;
      final newCount = confirmedSlot
          ? (match.joinedPlayerCount - 1).clamp(0, match.totalPlayersNeeded)
          : match.joinedPlayerCount;

      transaction.update(participantRef, {
        'attendanceStatus': attendanceStatus,
        'cancelledAt': Timestamp.fromDate(now),
        'withdrawalReason': reason,
      });
      transaction.set(userJoinedRef, {
        'attendanceStatus': attendanceStatus,
        'cancelledAt': Timestamp.fromDate(now),
        'withdrawalReason': reason,
      }, SetOptions(merge: true));

      if (confirmedSlot) {
        transaction.update(matchRef, {
          'joinedPlayerCount': newCount,
          'status': FootballMatch.statusForCount(
            newCount,
            match.totalPlayersNeeded,
          ),
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    });
  }

  Future<void> markParticipantAttended({
    required String matchId,
    required String userId,
  }) async {
    await _applyAttendanceOutcome(
      matchId: matchId,
      userId: userId,
      attendanceStatus: 'Attended',
    );
  }

  Future<void> markParticipantNoShow({
    required String matchId,
    required String userId,
  }) async {
    await _applyAttendanceOutcome(
      matchId: matchId,
      userId: userId,
      attendanceStatus: 'NoShow',
    );
  }

  Future<void> completeMatch(String matchId) async {
    final matchRef = _matches.doc(matchId);
    final matchSnapshot = await matchRef.get();
    if (!matchSnapshot.exists) throw Exception('Match not found.');
    final match = FootballMatch.fromFirestore(matchSnapshot);
    if (match.isCompleted) return;
    if (match.isCancelled) {
      throw Exception('Cancelled matches cannot complete.');
    }
    if (!match.hasStarted) {
      throw Exception('You can complete a match after kick-off.');
    }

    final participantsSnapshot = await matchRef
        .collection('participants')
        .get();
    final confirmedParticipants = participantsSnapshot.docs
        .map(MatchParticipant.fromFirestore)
        .where((participant) => participant.hasConfirmedSlot)
        .toList();
    if (confirmedParticipants.isEmpty) {
      throw Exception('Add confirmed players before completing this match.');
    }

    final now = DateTime.now();
    final batch = _firestore.batch();

    batch.update(matchRef, {
      'status': 'Completed',
      'completedAt': Timestamp.fromDate(now),
      'endDateTime': Timestamp.fromDate(
        match.endDateTime ??
            match.startDateTime.add(Duration(minutes: match.durationMinutes)),
      ),
      'updatedAt': Timestamp.fromDate(now),
    });

    // Flipping each confirmed player to Attended is all the client does.
    // The reliability reward + counters are applied server-side by
    // onParticipantReputation reacting to this status change.
    for (final participantDoc in participantsSnapshot.docs) {
      final participant = MatchParticipant.fromFirestore(participantDoc);
      if (participant.attendanceStatus != 'Joined') continue;

      batch.update(participantDoc.reference, {'attendanceStatus': 'Attended'});
      batch.set(
        _users.doc(participant.userId).collection('joinedMatches').doc(matchId),
        {'attendanceStatus': 'Attended'},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Stream<List<MatchComment>> commentsStream(String matchId) {
    return _matches
        .doc(matchId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MatchComment.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<void> addComment({
    required String matchId,
    required AppUser author,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('Comment is empty.');
    }
    final matchRef = _matches.doc(matchId);
    final matchSnapshot = await matchRef.get();
    if (!matchSnapshot.exists) throw Exception('Match not found.');

    final match = FootballMatch.fromFirestore(matchSnapshot);
    final participantSnapshot = await matchRef
        .collection('participants')
        .doc(author.uid)
        .get();
    final participant = participantSnapshot.exists
        ? MatchParticipant.fromFirestore(participantSnapshot)
        : null;
    final canComment =
        match.organiserId == author.uid ||
        participant?.hasConfirmedSlot == true ||
        participant?.isPendingPayment == true;
    if (!canComment) {
      throw Exception('Join this match before posting in the chat.');
    }

    final ref = _matches.doc(matchId).collection('comments').doc();
    final now = DateTime.now();
    final comment = MatchComment(
      id: ref.id,
      authorUid: author.uid,
      authorName: author.fullName,
      authorPhotoUrl: author.photoUrl,
      body: trimmed,
      createdAt: now,
    );
    await ref.set(comment.toMap());
  }

  Future<void> deleteComment({
    required String matchId,
    required String commentId,
  }) async {
    await _matches.doc(matchId).collection('comments').doc(commentId).delete();
  }

  /// Returns the current user's pending match invites, ordered most-recent
  /// first. Each invite carries a denormalised match snapshot so the home
  /// screen can render the card without a follow-up match fetch.
  Stream<List<Map<String, dynamic>>> matchInvitesStream(String uid) {
    return _users
        .doc(uid)
        .collection('matchInvites')
        .orderBy('invitedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => doc.data()).toList(growable: false),
        );
  }

  Future<void> inviteFriendsToMatch({
    required FootballMatch match,
    required String inviterUid,
    required String inviterName,
    required List<String> friendUids,
  }) async {
    if (friendUids.isEmpty) return;
    final now = DateTime.now();
    final batch = _firestore.batch();
    for (final friendUid in friendUids) {
      if (friendUid == inviterUid) continue;
      final ref = _users
          .doc(friendUid)
          .collection('matchInvites')
          .doc(match.id);
      batch.set(ref, {
        'matchId': match.id,
        'matchTitle': match.title,
        'matchDateTime': Timestamp.fromDate(match.startDateTime),
        'locationName': match.locationName,
        'format': match.format,
        'pricePerPlayer': match.pricePerPlayer,
        'inviterUid': inviterUid,
        'inviterName': inviterName,
        'invitedAt': Timestamp.fromDate(now),
      });
    }
    await batch.commit();
  }

  Future<void> dismissMatchInvite({
    required String uid,
    required String matchId,
  }) async {
    await _users.doc(uid).collection('matchInvites').doc(matchId).delete();
  }

  /// Cancels a match. Updates the match status + records the reason and
  /// timestamp, and propagates the cancelled state to every joined user's
  /// `joinedMatches` summary so their Home / My matches screens reflect it.
  Future<void> cancelMatch({
    required String matchId,
    required String reason,
  }) async {
    final matchRef = _matches.doc(matchId);
    final matchSnapshot = await matchRef.get();
    if (!matchSnapshot.exists) throw Exception('Match not found.');
    final match = FootballMatch.fromFirestore(matchSnapshot);
    if (match.isCancelled) return;
    if (match.isCompleted) {
      throw Exception('Completed matches cannot be cancelled.');
    }

    final now = DateTime.now();
    final batch = _firestore.batch();

    batch.update(matchRef, {
      'status': 'Cancelled',
      'cancelledAt': Timestamp.fromDate(now),
      'cancelReason': reason,
      'updatedAt': Timestamp.fromDate(now),
    });

    final participants = await matchRef.collection('participants').get();
    for (final doc in participants.docs) {
      final participant = MatchParticipant.fromFirestore(doc);
      batch.update(doc.reference, {
        'attendanceStatus': participant.hasConfirmedSlot
            ? 'Cancelled'
            : participant.attendanceStatus,
      });
      batch.set(
        _users.doc(participant.userId).collection('joinedMatches').doc(matchId),
        {
          'matchStatus': 'Cancelled',
          'cancelledAt': Timestamp.fromDate(now),
          'cancelReason': reason,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> _applyAttendanceOutcome({
    required String matchId,
    required String userId,
    required String attendanceStatus,
  }) async {
    final matchRef = _matches.doc(matchId);
    final participantRef = matchRef.collection('participants').doc(userId);
    final userJoinedRef = _users
        .doc(userId)
        .collection('joinedMatches')
        .doc(matchId);

    await _firestore.runTransaction((transaction) async {
      final participantSnapshot = await transaction.get(participantRef);
      if (!participantSnapshot.exists) {
        throw Exception('Participant not found.');
      }
      final participant = MatchParticipant.fromFirestore(participantSnapshot);
      if (participant.attendanceStatus == attendanceStatus) return;
      if (participant.isWithdrawn ||
          participant.isPendingApproval ||
          participant.isPendingPayment ||
          participant.isRejected) {
        throw Exception('This player does not have a confirmed place.');
      }

      // The reliability score, counters and event are applied server-side by
      // onParticipantReputation reacting to this attendance change.
      transaction.update(participantRef, {
        'attendanceStatus': attendanceStatus,
      });
      transaction.set(userJoinedRef, {
        'attendanceStatus': attendanceStatus,
      }, SetOptions(merge: true));
    });
  }

  // ----- Waitlist -------------------------------------------------------

  /// All waitlist entries on a match, oldest first (queue order).
  Stream<List<WaitlistEntry>> waitlistStream(String matchId) {
    return _matches
        .doc(matchId)
        .collection('waitlist')
        .orderBy('joinedAt')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(WaitlistEntry.fromFirestore).toList(),
        );
  }

  /// The current user's own waitlist entry on a match, or null.
  Stream<WaitlistEntry?> myWaitlistEntryStream(String matchId, String uid) {
    return _matches
        .doc(matchId)
        .collection('waitlist')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? WaitlistEntry.fromFirestore(doc) : null);
  }

  /// Join the waitlist for a full match. Promotion to an offered spot is
  /// handled server-side when a place opens up.
  Future<void> joinWaitlist({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    final matchRef = _matches.doc(match.id);
    final waitlistRef = matchRef.collection('waitlist').doc(user.uid);
    final participantRef = matchRef.collection('participants').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchRef);
      if (!matchSnapshot.exists) throw Exception('Match no longer exists.');
      final latestMatch = FootballMatch.fromFirestore(matchSnapshot);
      if (latestMatch.isCompleted || latestMatch.isCancelled) {
        throw Exception('This match is no longer open.');
      }
      if (latestMatch.hasStarted) {
        throw Exception('This match has already kicked off.');
      }

      final participantSnapshot = await transaction.get(participantRef);
      if (participantSnapshot.exists) {
        final participant = MatchParticipant.fromFirestore(participantSnapshot);
        if (participant.hasConfirmedSlot ||
            participant.isPendingPayment ||
            participant.isPendingApproval) {
          throw Exception('You already have a place in this match.');
        }
      }

      final existing = await transaction.get(waitlistRef);
      if (existing.exists) {
        throw Exception('You are already on the waitlist.');
      }

      final entry = WaitlistEntry(
        userId: user.uid,
        fullName: user.fullName,
        position: position,
        photoUrl: user.photoUrl,
        status: 'Waiting',
        joinedAt: DateTime.now(),
      );
      transaction.set(waitlistRef, entry.toMap());
    });
  }

  /// Leave the waitlist (whether still waiting or holding an offer).
  Future<void> leaveWaitlist({
    required String matchId,
    required String uid,
  }) async {
    await _matches
        .doc(matchId)
        .collection('waitlist')
        .doc(uid)
        .delete();
  }
}
