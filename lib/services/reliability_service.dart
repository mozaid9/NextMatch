import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/reliability_event.dart';

class ReliabilityService {
  ReliabilityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int attendMatchScoreChange = 1;
  static const int earlyCancellationPenalty = -1;
  static const int mediumCancellationPenalty = -3;
  static const int lateCancellationPenalty = -8;
  static const int noShowPenalty = -15;

  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  static int calculateWithdrawalPenalty(
    DateTime startDateTime,
    DateTime withdrawalTime,
  ) {
    final hoursUntilKickOff =
        startDateTime.difference(withdrawalTime).inMinutes / 60;
    if (hoursUntilKickOff > 24) return earlyCancellationPenalty;
    if (hoursUntilKickOff >= 6) return mediumCancellationPenalty;
    return lateCancellationPenalty;
  }

  static String withdrawalWarning(DateTime startDateTime, DateTime now) {
    final hoursUntilKickOff = startDateTime.difference(now).inHours;
    if (hoursUntilKickOff > 24) {
      return 'This should not affect your reliability much.';
    }
    if (hoursUntilKickOff >= 6) {
      return 'This may reduce your reliability.';
    }
    return 'This is a late withdrawal and will reduce your reliability.';
  }

  static String getReliabilityLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Risky';
    return 'Low';
  }

  static bool isLowReliability(int score, int threshold) => score < threshold;

  static int applyScoreChange(int currentScore, int scoreChange) {
    return (currentScore + scoreChange).clamp(0, 100).toInt();
  }

  Future<void> applyReliabilityEvent({
    required String userId,
    required String matchId,
    required String eventType,
    required int scoreChange,
    required String note,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final eventId = _uuid.v4();
    final eventRef = userRef.collection('reliabilityEvents').doc(eventId);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final data = userSnapshot.data() ?? <String, dynamic>{};
      final scoreBefore = (data['reliabilityScore'] as num?)?.toInt() ?? 100;
      final scoreAfter = applyScoreChange(scoreBefore, scoreChange);
      final now = DateTime.now();
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

      transaction.set(eventRef, event.toMap());
      transaction.set(userRef, {
        'reliabilityScore': scoreAfter,
        'lastReliabilityUpdateAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    });
  }
}
