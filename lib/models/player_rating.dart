import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerRating {
  const PlayerRating({
    required this.ratingId,
    required this.matchId,
    required this.ratedUserId,
    required this.ratedByUserId,
    required this.abilityRating,
    this.reliabilityFeedback,
    this.comment,
    required this.createdAt,
  });

  final String ratingId;
  final String matchId;
  final String ratedUserId;
  final String ratedByUserId;
  final double abilityRating;
  final String? reliabilityFeedback;
  final String? comment;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'ratingId': ratingId,
      'matchId': matchId,
      'ratedUserId': ratedUserId,
      'ratedByUserId': ratedByUserId,
      'abilityRating': abilityRating,
      'reliabilityFeedback': reliabilityFeedback,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
