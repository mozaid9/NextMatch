import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/player_rating.dart';

class RatingService {
  RatingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String ratingIdFor({
    required String ratedByUserId,
    required String ratedUserId,
  }) {
    return '${ratedByUserId}_$ratedUserId';
  }

  Future<bool> hasUserAlreadyRated({
    required String matchId,
    required String ratedUserId,
    required String ratedByUserId,
  }) async {
    final ratingId = ratingIdFor(
      ratedByUserId: ratedByUserId,
      ratedUserId: ratedUserId,
    );
    final snapshot = await _firestore
        .collection('matches')
        .doc(matchId)
        .collection('ratings')
        .doc(ratingId)
        .get();
    return snapshot.exists;
  }

  Future<void> submitPlayerRating({
    required String matchId,
    required String ratedUserId,
    required String ratedByUserId,
    required double rating,
    String? comment,
    String? reliabilityFeedback,
  }) async {
    if (ratedUserId == ratedByUserId) {
      throw Exception('You cannot rate yourself.');
    }
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5.');
    }

    final ratingId = ratingIdFor(
      ratedByUserId: ratedByUserId,
      ratedUserId: ratedUserId,
    );
    final matchRef = _firestore.collection('matches').doc(matchId);
    final matchRatingRef = matchRef.collection('ratings').doc(ratingId);
    final ratedParticipantRef = matchRef
        .collection('participants')
        .doc(ratedUserId);
    final raterParticipantRef = matchRef
        .collection('participants')
        .doc(ratedByUserId);

    // The client only writes the rating doc (and flags the match rated). The
    // rated player's ability aggregate is recomputed server-side by
    // onRatingCreated, so a player can never inflate their own score.
    await _firestore.runTransaction((transaction) async {
      final matchSnapshot = await transaction.get(matchRef);
      final existingRating = await transaction.get(matchRatingRef);
      final ratedParticipantSnapshot = await transaction.get(
        ratedParticipantRef,
      );
      final raterParticipantSnapshot = await transaction.get(
        raterParticipantRef,
      );

      if (!matchSnapshot.exists) throw Exception('Match not found.');
      final matchData = matchSnapshot.data() ?? <String, dynamic>{};
      if (matchData['status'] != 'Completed') {
        throw Exception('Ratings open after the match is completed.');
      }
      if (existingRating.exists) {
        throw Exception('You have already rated this player.');
      }
      if (!ratedParticipantSnapshot.exists ||
          !raterParticipantSnapshot.exists) {
        throw Exception('Both players must have played this match.');
      }

      final ratedStatus =
          ratedParticipantSnapshot.data()?['attendanceStatus'] as String?;
      final raterStatus =
          raterParticipantSnapshot.data()?['attendanceStatus'] as String?;
      if (ratedStatus != 'Attended' || raterStatus != 'Attended') {
        throw Exception('Only attended players can rate attended players.');
      }

      final playerRating = PlayerRating(
        ratingId: ratingId,
        matchId: matchId,
        ratedUserId: ratedUserId,
        ratedByUserId: ratedByUserId,
        abilityRating: rating,
        reliabilityFeedback: reliabilityFeedback,
        comment: comment,
        createdAt: DateTime.now(),
      );

      transaction.set(matchRatingRef, playerRating.toMap());
      transaction.set(matchRef, {'isRated': true}, SetOptions(merge: true));
    });
  }
}
