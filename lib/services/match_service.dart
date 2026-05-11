import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/currency_helpers.dart';
import '../models/app_user.dart';
import '../models/football_match.dart';
import '../models/match_participant.dart';
import '../models/payment_record.dart';

class MatchService {
  MatchService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _matches =>
      _firestore.collection('matches');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  Stream<List<FootballMatch>> openMatchesStream() {
    return _matches.orderBy('startDateTime').snapshots().map((snapshot) {
      return snapshot.docs
          .map(FootballMatch.fromFirestore)
          .where(
            (match) =>
                match.visibility == 'Public' &&
                match.status != 'Full' &&
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
    return _firestore
        .collection('users')
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
    final newMatch = match.copyWith(
      id: docRef.id,
      status: FootballMatch.statusForCount(
        match.joinedPlayerCount,
        match.totalPlayersNeeded,
      ),
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(newMatch.toMap());
    return docRef.id;
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
    final userJoinedRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('joinedMatches')
        .doc(match.id);
    final paymentId = _uuid.v4();
    final paymentRef = _payments.doc(paymentId);

    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchRef);
      if (!matchSnapshot.exists) {
        throw Exception('Match no longer exists.');
      }

      final latestMatch = FootballMatch.fromFirestore(matchSnapshot);
      if (latestMatch.joinedPlayerCount >= latestMatch.totalPlayersNeeded) {
        throw Exception('This match is already full.');
      }

      final existingParticipant = await transaction.get(participantRef);
      if (existingParticipant.exists) {
        throw Exception('You are already in this match.');
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
        paymentStatus: 'Confirmed',
        joinedAt: joinedAt,
        amountPaid: total,
        attendanceStatus: 'Confirmed',
      );

      final newCount = latestMatch.joinedPlayerCount + 1;
      final newStatus = FootballMatch.statusForCount(
        newCount,
        latestMatch.totalPlayersNeeded,
      );

      transaction.set(paymentRef, payment.toMap());
      transaction.set(participantRef, participant.toMap());
      transaction.set(userJoinedRef, {
        'matchId': latestMatch.id,
        'joinedAt': Timestamp.fromDate(joinedAt),
        'paymentStatus': 'Confirmed',
        'position': position,
        'matchDateTime': Timestamp.fromDate(latestMatch.startDateTime),
      });
      transaction.update(matchRef, {
        'joinedPlayerCount': newCount,
        'status': newStatus,
        'updatedAt': Timestamp.fromDate(joinedAt),
      });
    });
  }

  Future<void> seedDemoMatches(AppUser organiser) async {
    // MVP helper used by empty states so a fresh Firebase project has games to
    // browse without requiring a separate admin dashboard.
    final now = DateTime.now();
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
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final sample in samples) {
      await createMatch(sample);
    }
  }
}
