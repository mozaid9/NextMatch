import 'package:cloud_firestore/cloud_firestore.dart';

class MatchParticipant {
  const MatchParticipant({
    required this.userId,
    required this.fullName,
    required this.position,
    required this.skillLevel,
    required this.paymentStatus,
    required this.joinedAt,
    required this.amountPaid,
    required this.attendanceStatus,
  });

  final String userId;
  final String fullName;
  final String position;
  final String skillLevel;
  final String paymentStatus;
  final DateTime joinedAt;
  final double amountPaid;
  final String attendanceStatus;

  factory MatchParticipant.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return MatchParticipant(
      userId: data['userId'] as String? ?? document.id,
      fullName: data['fullName'] as String? ?? '',
      position: data['position'] as String? ?? 'Any',
      skillLevel: data['skillLevel'] as String? ?? 'Casual',
      paymentStatus: data['paymentStatus'] as String? ?? 'Pending',
      joinedAt: _readDate(data['joinedAt']),
      amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? 0,
      attendanceStatus: data['attendanceStatus'] as String? ?? 'Confirmed',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'position': position,
      'skillLevel': skillLevel,
      'paymentStatus': paymentStatus,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'amountPaid': amountPaid,
      'attendanceStatus': attendanceStatus,
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
