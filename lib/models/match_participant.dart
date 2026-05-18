import 'package:cloud_firestore/cloud_firestore.dart';

class MatchParticipant {
  const MatchParticipant({
    required this.userId,
    required this.fullName,
    required this.position,
    required this.skillLevel,
    required this.abilityRatingAtJoin,
    required this.reliabilityScoreAtJoin,
    required this.paymentStatus,
    required this.joinedAt,
    this.cancelledAt,
    this.approvedAt,
    this.rejectedAt,
    required this.amountPaid,
    this.amountOwed = 0,
    required this.attendanceStatus,
    this.organiserApproved = true,
    this.requiresApproval = false,
    this.withdrawalReason,
    this.paymentDeadline,
    this.photoUrl,
  });

  final String userId;
  final String fullName;
  final String position;
  final String skillLevel;
  final double abilityRatingAtJoin;
  final int reliabilityScoreAtJoin;
  final String paymentStatus;
  final DateTime joinedAt;
  final DateTime? cancelledAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final double amountPaid;
  final double amountOwed;
  final String attendanceStatus;
  final bool organiserApproved;
  final bool requiresApproval;
  final String? withdrawalReason;
  final DateTime? paymentDeadline;
  /// Snapshot of the player's profile photo at join time. Lets organiser
  /// dashboards / match detail / co-players strip render real avatars.
  final String? photoUrl;

  bool get hasConfirmedSlot =>
      attendanceStatus == 'Joined' ||
      attendanceStatus == 'Attended' ||
      attendanceStatus == 'NoShow';

  bool get isPendingPayment => attendanceStatus == 'PendingPayment';
  bool get isPendingApproval => attendanceStatus == 'PendingApproval';

  bool get isPaymentOverdue =>
      paymentDeadline != null &&
      DateTime.now().isAfter(paymentDeadline!) &&
      isPendingPayment;

  Duration? get timeUntilDeadline =>
      paymentDeadline == null ? null : paymentDeadline!.difference(DateTime.now());

  bool get isRejected => attendanceStatus == 'Rejected';
  bool get isWithdrawn =>
      attendanceStatus == 'Cancelled' || attendanceStatus == 'LateCancelled';
  bool get canWithdraw =>
      attendanceStatus == 'Joined' || isPendingPayment || isPendingApproval;

  factory MatchParticipant.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return MatchParticipant(
      userId: data['userId'] as String? ?? document.id,
      fullName: data['fullName'] as String? ?? '',
      position: data['position'] as String? ?? 'Any',
      skillLevel: data['skillLevel'] as String? ?? 'Casual',
      abilityRatingAtJoin:
          (data['abilityRatingAtJoin'] as num?)?.toDouble() ?? 3.0,
      reliabilityScoreAtJoin:
          (data['reliabilityScoreAtJoin'] as num?)?.toInt() ?? 100,
      paymentStatus: data['paymentStatus'] as String? ?? 'Pending',
      joinedAt: _readDate(data['joinedAt']),
      cancelledAt: _readNullableDate(data['cancelledAt']),
      approvedAt: _readNullableDate(data['approvedAt']),
      rejectedAt: _readNullableDate(data['rejectedAt']),
      amountPaid: (data['amountPaid'] as num?)?.toDouble() ?? 0,
      amountOwed: (data['amountOwed'] as num?)?.toDouble() ?? 0,
      attendanceStatus: _normaliseAttendanceStatus(
        data['attendanceStatus'] as String?,
      ),
      organiserApproved: data['organiserApproved'] as bool? ?? true,
      requiresApproval: data['requiresApproval'] as bool? ?? false,
      withdrawalReason: data['withdrawalReason'] as String?,
      paymentDeadline: _readNullableDate(data['paymentDeadline']),
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'position': position,
      'skillLevel': skillLevel,
      'abilityRatingAtJoin': abilityRatingAtJoin,
      'reliabilityScoreAtJoin': reliabilityScoreAtJoin,
      'paymentStatus': paymentStatus,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'cancelledAt': cancelledAt == null
          ? null
          : Timestamp.fromDate(cancelledAt!),
      'approvedAt': approvedAt == null ? null : Timestamp.fromDate(approvedAt!),
      'rejectedAt': rejectedAt == null ? null : Timestamp.fromDate(rejectedAt!),
      'amountPaid': amountPaid,
      'amountOwed': amountOwed,
      'attendanceStatus': attendanceStatus,
      'organiserApproved': organiserApproved,
      'requiresApproval': requiresApproval,
      'withdrawalReason': withdrawalReason,
      'paymentDeadline': paymentDeadline == null ? null : Timestamp.fromDate(paymentDeadline!),
      'photoUrl': photoUrl,
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static DateTime? _readNullableDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _normaliseAttendanceStatus(String? value) {
    return switch (value) {
      null || '' => 'Joined',
      'Confirmed' => 'Joined',
      _ => value,
    };
  }
}
