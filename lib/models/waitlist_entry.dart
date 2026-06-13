import 'package:cloud_firestore/cloud_firestore.dart';

/// A player waiting for a spot on a full match. Lives at
/// `matches/{matchId}/waitlist/{uid}`. Status transitions after creation
/// (Offered / Claimed / Expired) are written only by the backend.
class WaitlistEntry {
  const WaitlistEntry({
    required this.userId,
    required this.fullName,
    required this.position,
    this.photoUrl,
    required this.status,
    required this.joinedAt,
    this.offeredAt,
    this.offerExpiresAt,
  });

  final String userId;
  final String fullName;
  final String position;
  final String? photoUrl;

  /// Waiting | Offered | Claimed | Expired
  final String status;
  final DateTime joinedAt;
  final DateTime? offeredAt;
  final DateTime? offerExpiresAt;

  bool get isWaiting => status == 'Waiting';
  bool get isOffered => status == 'Offered';

  /// An offer the player can still act on.
  bool get hasLiveOffer =>
      isOffered &&
      offerExpiresAt != null &&
      offerExpiresAt!.isAfter(DateTime.now());

  Duration? get timeLeft => offerExpiresAt?.difference(DateTime.now());

  factory WaitlistEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return WaitlistEntry(
      userId: data['userId'] as String? ?? document.id,
      fullName: data['fullName'] as String? ?? '',
      position: data['position'] as String? ?? 'Any',
      photoUrl: data['photoUrl'] as String?,
      status: data['status'] as String? ?? 'Waiting',
      joinedAt: _readDate(data['joinedAt']),
      offeredAt: _readNullableDate(data['offeredAt']),
      offerExpiresAt: _readNullableDate(data['offerExpiresAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'position': position,
      'photoUrl': photoUrl,
      'status': status,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'offeredAt': offeredAt == null ? null : Timestamp.fromDate(offeredAt!),
      'offerExpiresAt':
          offerExpiresAt == null ? null : Timestamp.fromDate(offerExpiresAt!),
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
}
