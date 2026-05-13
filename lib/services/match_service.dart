import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/currency_helpers.dart';
import '../models/app_user.dart';
import '../models/football_match.dart';
import '../models/match_participant.dart';
import '../models/payment_record.dart';
import '../models/reliability_event.dart';
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
  final Uuid _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _matches =>
      _firestore.collection('matches');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<List<FootballMatch>> openMatchesStream() {
    return _matches.orderBy('startDateTime').snapshots().map((snapshot) {
      return snapshot.docs
          .map(FootballMatch.fromFirestore)
          .where(
            (match) =>
                match.visibility == 'Public' &&
                match.status != 'Full' &&
                match.status != 'Completed' &&
                match.status != 'Cancelled' &&
                match.startDateTime.isAfter(
                  DateTime.now().subtract(const Duration(hours: 2)),
                ),
          )
          .toList();
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
    return _matches
        .where('organiserId', isEqualTo: uid)
        .orderBy('startDateTime')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(FootballMatch.fromFirestore).toList(),
        );
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

      final requiresApproval =
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
        });

        return const JoinRequestResult(
          requiresApproval: false,
          canContinueToPayment: false,
          message:
              'You have joined this match view. Pay when ready to secure your spot.',
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
            'Your request has been sent to the organiser because your reliability score is below this match’s requirement.',
      );
    });
  }

  Future<void> confirmMockPaymentAndJoin({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    // TODO(Cloud Functions): Move paid join fulfilment server-side when Stripe is
    // live. The client should never be the final authority on payment success.
    final matchRef = _matches.doc(match.id);
    final participantRef = matchRef.collection('participants').doc(user.uid);
    final userJoinedRef = _users
        .doc(user.uid)
        .collection('joinedMatches')
        .doc(match.id);
    final paymentId = _uuid.v4();
    final paymentRef = _payments.doc(paymentId);

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchRef);
      if (!matchSnapshot.exists) throw Exception('Match no longer exists.');

      final latestMatch = FootballMatch.fromFirestore(matchSnapshot);
      if (latestMatch.isFull) throw Exception('This match is already full.');
      if (latestMatch.isCompleted || latestMatch.isCancelled) {
        throw Exception('This match is no longer open.');
      }

      final participantSnapshot = await transaction.get(participantRef);
      MatchParticipant? existingParticipant;
      if (participantSnapshot.exists) {
        existingParticipant = MatchParticipant.fromFirestore(
          participantSnapshot,
        );
        if (existingParticipant.isPendingApproval &&
            !existingParticipant.organiserApproved) {
          throw Exception('This spot still needs organiser approval.');
        }
        if (existingParticipant.hasConfirmedSlot) {
          throw Exception('You are already in this match.');
        }
        if (existingParticipant.isRejected || existingParticipant.isWithdrawn) {
          throw Exception('This match request is no longer active.');
        }
        if (!existingParticipant.isPendingApproval &&
            !existingParticipant.isPendingPayment) {
          throw Exception('This place cannot be paid for yet.');
        }
      }

      final joinedAt = DateTime.now();
      final platformFee = CurrencyHelpers.mockPlatformFee(
        latestMatch.pricePerPlayer,
      );
      final total = CurrencyHelpers.roundMoney(
        latestMatch.pricePerPlayer + platformFee,
      );

      final payment = PaymentRecord(
        paymentId: paymentId,
        userId: user.uid,
        matchId: latestMatch.id,
        organiserId: latestMatch.organiserId,
        amount: latestMatch.pricePerPlayer,
        platformFee: platformFee,
        total: total,
        status: 'Succeeded',
        paymentProvider: 'mock',
        mockPayment: true,
        createdAt: joinedAt,
      );

      final participant = MatchParticipant(
        userId: user.uid,
        fullName: user.fullName,
        position: position,
        skillLevel: user.skillLevel,
        abilityRatingAtJoin: user.abilityRating,
        reliabilityScoreAtJoin: user.reliabilityScore,
        paymentStatus: 'Confirmed',
        joinedAt: existingParticipant?.joinedAt ?? joinedAt,
        approvedAt: existingParticipant?.approvedAt,
        amountPaid: total,
        amountOwed: 0,
        attendanceStatus: 'Joined',
        organiserApproved: true,
        requiresApproval: false,
      );

      final newCount = latestMatch.joinedPlayerCount + 1;
      final newStatus = FootballMatch.statusForCount(
        newCount,
        latestMatch.totalPlayersNeeded,
      );

      transaction.set(paymentRef, payment.toMap());
      transaction.set(
        participantRef,
        participant.toMap(),
        SetOptions(merge: true),
      );
      transaction.set(userJoinedRef, {
        'matchId': latestMatch.id,
        'joinedAt': Timestamp.fromDate(
          existingParticipant?.joinedAt ?? joinedAt,
        ),
        'paymentStatus': 'Confirmed',
        'attendanceStatus': 'Joined',
        'position': position,
        'matchDateTime': Timestamp.fromDate(latestMatch.startDateTime),
        'amountOwed': 0,
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
        transaction.update(participantRef, update);
        transaction.set(userJoinedRef, {
          'paymentStatus': 'ApprovedPendingPayment',
          'attendanceStatus': 'PendingPayment',
          'organiserApproved': true,
          'requiresApproval': false,
          'approvedAt': Timestamp.fromDate(now),
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
      final userSnapshot = await transaction.get(userRef);
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
      final scoreBefore =
          (userSnapshot.data()?['reliabilityScore'] as num?)?.toInt() ?? 100;
      final scoreAfter = ReliabilityService.applyScoreChange(
        scoreBefore,
        penalty,
      );

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
        transaction.set(userRef, {
          'reliabilityScore': scoreAfter,
          'cancelledMatches': FieldValue.increment(1),
          if (isLate) 'lateCancellations': FieldValue.increment(1),
          'lastReliabilityUpdateAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        final eventId = _uuid.v4();
        final event = ReliabilityEvent(
          eventId: eventId,
          matchId: matchId,
          eventType: isLate ? 'LateCancellation' : 'EarlyCancellation',
          scoreChange: penalty,
          scoreBefore: scoreBefore,
          scoreAfter: scoreAfter,
          createdAt: now,
          note: reason ?? 'Player withdrew before kick-off.',
        );
        transaction.set(
          userRef.collection('reliabilityEvents').doc(eventId),
          event.toMap(),
        );
      }

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
      eventType: 'OrganiserMarkedAttended',
      scoreChange: ReliabilityService.attendMatchScoreChange,
      note: 'Organiser marked player as attended.',
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
      eventType: 'OrganiserMarkedNoShow',
      scoreChange: ReliabilityService.noShowPenalty,
      note: 'Organiser marked player as no-show.',
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

    for (final participantDoc in participantsSnapshot.docs) {
      final participant = MatchParticipant.fromFirestore(participantDoc);
      if (participant.attendanceStatus != 'Joined') continue;

      final userRef = _users.doc(participant.userId);
      final userSnapshot = await userRef.get();
      final scoreBefore =
          (userSnapshot.data()?['reliabilityScore'] as num?)?.toInt() ?? 100;
      final scoreAfter = ReliabilityService.applyScoreChange(
        scoreBefore,
        ReliabilityService.attendMatchScoreChange,
      );
      final eventId = _uuid.v4();
      final event = ReliabilityEvent(
        eventId: eventId,
        matchId: matchId,
        eventType: 'MatchCompleted',
        scoreChange: ReliabilityService.attendMatchScoreChange,
        scoreBefore: scoreBefore,
        scoreAfter: scoreAfter,
        createdAt: now,
        note: 'Match completed and player attended.',
      );

      batch.update(participantDoc.reference, {'attendanceStatus': 'Attended'});
      batch.set(userRef, {
        'reliabilityScore': scoreAfter,
        'attendedMatches': FieldValue.increment(1),
        'completedMatches': FieldValue.increment(1),
        'matchesPlayed': FieldValue.increment(1),
        'lastReliabilityUpdateAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      batch.set(
        userRef.collection('reliabilityEvents').doc(eventId),
        event.toMap(),
      );
      batch.set(userRef.collection('joinedMatches').doc(matchId), {
        'attendanceStatus': 'Attended',
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> _applyAttendanceOutcome({
    required String matchId,
    required String userId,
    required String attendanceStatus,
    required String eventType,
    required int scoreChange,
    required String note,
  }) async {
    final matchRef = _matches.doc(matchId);
    final participantRef = matchRef.collection('participants').doc(userId);
    final userRef = _users.doc(userId);
    final userJoinedRef = userRef.collection('joinedMatches').doc(matchId);

    await _firestore.runTransaction((transaction) async {
      final participantSnapshot = await transaction.get(participantRef);
      final userSnapshot = await transaction.get(userRef);
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

      final now = DateTime.now();
      final scoreBefore =
          (userSnapshot.data()?['reliabilityScore'] as num?)?.toInt() ?? 100;
      final scoreAfter = ReliabilityService.applyScoreChange(
        scoreBefore,
        scoreChange,
      );
      final eventId = _uuid.v4();
      final event = ReliabilityEvent(
        eventId: eventId,
        matchId: matchId,
        eventType: eventType,
        scoreChange: scoreChange,
        scoreBefore: scoreBefore,
        scoreAfter: scoreAfter,
        createdAt: now,
        note: note,
      );

      transaction.update(participantRef, {
        'attendanceStatus': attendanceStatus,
      });
      transaction.set(userJoinedRef, {
        'attendanceStatus': attendanceStatus,
      }, SetOptions(merge: true));
      transaction.set(userRef, {
        'reliabilityScore': scoreAfter,
        if (attendanceStatus == 'Attended') ...{
          'attendedMatches': FieldValue.increment(1),
          'completedMatches': FieldValue.increment(1),
          'matchesPlayed': FieldValue.increment(1),
        },
        if (attendanceStatus == 'NoShow') 'noShows': FieldValue.increment(1),
        'lastReliabilityUpdateAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      transaction.set(
        userRef.collection('reliabilityEvents').doc(eventId),
        event.toMap(),
      );
    });
  }

  Future<void> seedDemoMatches(AppUser organiser) async {
    final now = DateTime.now();
    await _seedDemoUsers(now);

    final samples = [
      FootballMatch(
        id: '',
        title: 'Friday Night 7s',
        organiserId: organiser.uid,
        organiserName: organiser.fullName,
        locationName: 'Manchester Powerleague',
        address: 'Central Manchester',
        date: now.add(const Duration(days: 5)),
        startTime: '19:30',
        startDateTime: DateTime(now.year, now.month, now.day + 5, 19, 30),
        endDateTime: DateTime(now.year, now.month, now.day + 5, 20, 30),
        durationMinutes: 60,
        format: '7-a-side',
        totalPlayersNeeded: 14,
        joinedPlayerCount: 0,
        pricePerPlayer: 6.50,
        skillLevel: 'Intermediate',
        pitchType: 'Astro',
        description: 'Fast but friendly Friday night football.',
        neededPositions: const {
          'Goalkeepers': 2,
          'Defenders': 4,
          'Midfielders': 4,
          'Forwards': 4,
        },
        visibility: 'Public',
        status: 'Open',
        cancellationPolicy: 'Refunds are handled manually in the MVP.',
        paymentMode: 'Split',
        createdAt: now,
        updatedAt: now,
      ),
      FootballMatch(
        id: '',
        title: 'Casual 5-a-side',
        organiserId: organiser.uid,
        organiserName: organiser.fullName,
        locationName: 'Local Sports Centre',
        address: 'Community sports hall',
        date: now.add(const Duration(days: 2)),
        startTime: '18:00',
        startDateTime: DateTime(now.year, now.month, now.day + 2, 18),
        endDateTime: DateTime(now.year, now.month, now.day + 2, 18, 50),
        durationMinutes: 50,
        format: '5-a-side',
        totalPlayersNeeded: 10,
        joinedPlayerCount: 0,
        pricePerPlayer: 5.00,
        skillLevel: 'Casual',
        pitchType: 'Indoor',
        description: 'Low-pressure game for a run about after work.',
        neededPositions: const {
          'Goalkeepers': 2,
          'Defenders': 2,
          'Midfielders': 4,
          'Forwards': 2,
        },
        visibility: 'Public',
        status: 'Open',
        cancellationPolicy: 'Refunds are handled manually in the MVP.',
        paymentMode: 'OrganiserPays',
        createdAt: now,
        updatedAt: now,
      ),
      FootballMatch(
        id: '',
        title: 'Competitive 11-a-side Trial Game',
        organiserId: organiser.uid,
        organiserName: organiser.fullName,
        locationName: 'Outdoor Grass Pitch',
        address: 'North field complex',
        date: now.add(const Duration(days: 9)),
        startTime: '10:00',
        startDateTime: DateTime(now.year, now.month, now.day + 9, 10),
        endDateTime: DateTime(now.year, now.month, now.day + 9, 11, 30),
        durationMinutes: 90,
        format: '11-a-side',
        totalPlayersNeeded: 22,
        joinedPlayerCount: 0,
        pricePerPlayer: 8.00,
        skillLevel: 'Advanced',
        pitchType: 'Grass',
        description: 'High-tempo 11s for players looking for a serious game.',
        neededPositions: const {
          'Goalkeepers': 2,
          'Defenders': 8,
          'Midfielders': 8,
          'Forwards': 4,
        },
        visibility: 'Public',
        status: 'Open',
        cancellationPolicy: 'Refunds are handled manually in the MVP.',
        paymentMode: 'Split',
        createdAt: now,
        updatedAt: now,
      ),
      FootballMatch(
        id: '',
        title: 'Trust Test 7s',
        organiserId: organiser.uid,
        organiserName: organiser.fullName,
        locationName: 'Salford Sports Village',
        address: 'Littleton Road, Salford',
        date: now.add(const Duration(days: 3)),
        startTime: '20:00',
        startDateTime: DateTime(now.year, now.month, now.day + 3, 20),
        endDateTime: DateTime(now.year, now.month, now.day + 3, 21),
        durationMinutes: 60,
        format: '7-a-side',
        totalPlayersNeeded: 14,
        joinedPlayerCount: 0,
        pricePerPlayer: 6.00,
        skillLevel: 'Intermediate',
        pitchType: '3G/4G',
        description:
            'Open match requiring approval for players below 70 reliability.',
        neededPositions: const {
          'Goalkeepers': 2,
          'Defenders': 4,
          'Midfielders': 4,
          'Forwards': 4,
        },
        visibility: 'Public',
        status: 'Open',
        cancellationPolicy:
            'Late withdrawals reduce reliability. Stripe refunds are TODO.',
        paymentMode: 'Split',
        minimumReliabilityRequired: 70,
        requiresApprovalForLowReliability: true,
        createdAt: now,
        updatedAt: now,
      ),
      FootballMatch(
        id: '',
        title: 'Completed Demo 5s',
        organiserId: organiser.uid,
        organiserName: organiser.fullName,
        locationName: 'City Football Dome',
        address: 'Demo Road, Manchester',
        date: now.subtract(const Duration(days: 2)),
        startTime: '18:30',
        startDateTime: DateTime(now.year, now.month, now.day - 2, 18, 30),
        endDateTime: DateTime(now.year, now.month, now.day - 2, 19, 20),
        durationMinutes: 50,
        format: '5-a-side',
        totalPlayersNeeded: 10,
        joinedPlayerCount: 2,
        pricePerPlayer: 5.00,
        skillLevel: 'Casual',
        pitchType: 'Indoor',
        description: 'Completed demo match for post-match ratings.',
        neededPositions: const {
          'Goalkeepers': 2,
          'Defenders': 2,
          'Midfielders': 4,
          'Forwards': 2,
        },
        visibility: 'Public',
        status: 'Completed',
        cancellationPolicy: 'Completed demo.',
        paymentMode: 'OrganiserPays',
        completedAt: now.subtract(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final sample in samples) {
      final id = await createMatch(sample);
      if (sample.status == 'Completed') {
        await _seedCompletedParticipants(id, sample, now);
      }
    }
  }

  Future<void> _seedDemoUsers(DateTime now) async {
    final batch = _firestore.batch();
    batch.set(_users.doc('demo-excellent-player'), {
      'uid': 'demo-excellent-player',
      'fullName': 'Alex Reliable',
      'email': 'alex.reliable@example.com',
      'age': 29,
      'location': 'Manchester',
      'preferredPosition': 'Midfielder',
      'secondaryPosition': 'Defender',
      'skillLevel': 'Intermediate',
      'favouriteFoot': 'Right',
      'bio': 'Turns up early and keeps the game moving.',
      'photoUrl': null,
      'reliabilityScore': 98,
      'abilityRating': 4.2,
      'rating': 4.2,
      'abilityRatingCount': 9,
      'completedMatches': 12,
      'cancelledMatches': 0,
      'lateCancellations': 0,
      'noShows': 0,
      'attendedMatches': 12,
      'matchesPlayed': 12,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
    batch.set(_users.doc('demo-low-reliability-player'), {
      'uid': 'demo-low-reliability-player',
      'fullName': 'Sam Lastminute',
      'email': 'sam.lastminute@example.com',
      'age': 24,
      'location': 'Salford',
      'preferredPosition': 'Forward',
      'secondaryPosition': 'Any',
      'skillLevel': 'Casual',
      'favouriteFoot': 'Left',
      'bio': 'Talented, but needs organiser approval for stricter games.',
      'photoUrl': null,
      'reliabilityScore': 52,
      'abilityRating': 3.6,
      'rating': 3.6,
      'abilityRatingCount': 5,
      'completedMatches': 4,
      'cancelledMatches': 3,
      'lateCancellations': 2,
      'noShows': 1,
      'attendedMatches': 4,
      'matchesPlayed': 4,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> _seedCompletedParticipants(
    String matchId,
    FootballMatch match,
    DateTime now,
  ) async {
    final matchRef = _matches.doc(matchId);
    final batch = _firestore.batch();
    final players = [
      MatchParticipant(
        userId: 'demo-excellent-player',
        fullName: 'Alex Reliable',
        position: 'Midfielder',
        skillLevel: 'Intermediate',
        abilityRatingAtJoin: 4.2,
        reliabilityScoreAtJoin: 98,
        paymentStatus: 'Owed',
        joinedAt: _demoDate,
        amountPaid: 0,
        amountOwed: 5,
        attendanceStatus: 'Attended',
      ),
      MatchParticipant(
        userId: 'demo-low-reliability-player',
        fullName: 'Sam Lastminute',
        position: 'Forward',
        skillLevel: 'Casual',
        abilityRatingAtJoin: 3.6,
        reliabilityScoreAtJoin: 52,
        paymentStatus: 'Owed',
        joinedAt: _demoDate,
        amountPaid: 0,
        amountOwed: 5,
        attendanceStatus: 'Attended',
      ),
    ];

    for (final player in players) {
      final participant = MatchParticipant(
        userId: player.userId,
        fullName: player.fullName,
        position: player.position,
        skillLevel: player.skillLevel,
        abilityRatingAtJoin: player.abilityRatingAtJoin,
        reliabilityScoreAtJoin: player.reliabilityScoreAtJoin,
        paymentStatus: player.paymentStatus,
        joinedAt: now.subtract(const Duration(days: 2, hours: 2)),
        amountPaid: player.amountPaid,
        amountOwed: player.amountOwed,
        attendanceStatus: player.attendanceStatus,
      );
      batch.set(
        matchRef.collection('participants').doc(player.userId),
        participant.toMap(),
      );
      batch.set(
        _users.doc(player.userId).collection('joinedMatches').doc(matchId),
        {
          'matchId': matchId,
          'joinedAt': Timestamp.fromDate(participant.joinedAt),
          'paymentStatus': 'Owed',
          'attendanceStatus': 'Attended',
          'position': participant.position,
          'matchDateTime': Timestamp.fromDate(match.startDateTime),
          'amountOwed': match.pricePerPlayer,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}

final _demoDate = DateTime(2026);
