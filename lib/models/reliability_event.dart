import 'package:cloud_firestore/cloud_firestore.dart';

class ReliabilityEvent {
  const ReliabilityEvent({
    required this.eventId,
    required this.matchId,
    required this.eventType,
    required this.scoreChange,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.createdAt,
    required this.note,
  });

  final String eventId;
  final String matchId;
  final String eventType;
  final int scoreChange;
  final int scoreBefore;
  final int scoreAfter;
  final DateTime createdAt;
  final String note;

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'matchId': matchId,
      'eventType': eventType,
      'scoreChange': scoreChange,
      'scoreBefore': scoreBefore,
      'scoreAfter': scoreAfter,
      'createdAt': Timestamp.fromDate(createdAt),
      'note': note,
    };
  }
}
