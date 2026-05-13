import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.age,
    required this.location,
    required this.preferredPosition,
    required this.secondaryPosition,
    required this.skillLevel,
    required this.favouriteFoot,
    required this.bio,
    this.photoUrl,
    this.reliabilityScore = 100,
    this.abilityRating = 3.0,
    this.abilityRatingCount = 0,
    this.completedMatches = 0,
    this.cancelledMatches = 0,
    this.lateCancellations = 0,
    this.noShows = 0,
    this.attendedMatches = 0,
    this.lastReliabilityUpdateAt,
    this.lastAbilityRatingAt,
    this.matchesPlayed = 0,
    this.rating = 3.0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String fullName;
  final String email;
  final int age;
  final String location;
  final String preferredPosition;
  final String secondaryPosition;
  final String skillLevel;
  final String favouriteFoot;
  final String bio;
  final String? photoUrl;
  final int reliabilityScore;
  final double abilityRating;
  final int abilityRatingCount;
  final int completedMatches;
  final int cancelledMatches;
  final int lateCancellations;
  final int noShows;
  final int attendedMatches;
  final DateTime? lastReliabilityUpdateAt;
  final DateTime? lastAbilityRatingAt;
  final int matchesPlayed;
  // Legacy alias kept while older UI/data migrates to abilityRating.
  final double rating;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return AppUser.fromMap(data, document.id);
  }

  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: data['uid'] as String? ?? uid,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      location: data['location'] as String? ?? '',
      preferredPosition: data['preferredPosition'] as String? ?? 'Any',
      secondaryPosition: data['secondaryPosition'] as String? ?? 'Any',
      skillLevel: data['skillLevel'] as String? ?? 'Casual',
      favouriteFoot: data['favouriteFoot'] as String? ?? 'Right',
      bio: data['bio'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      reliabilityScore: (data['reliabilityScore'] as num?)?.toInt() ?? 100,
      abilityRating:
          (data['abilityRating'] as num?)?.toDouble() ??
          (data['rating'] as num?)?.toDouble() ??
          3.0,
      abilityRatingCount: (data['abilityRatingCount'] as num?)?.toInt() ?? 0,
      completedMatches: (data['completedMatches'] as num?)?.toInt() ?? 0,
      cancelledMatches: (data['cancelledMatches'] as num?)?.toInt() ?? 0,
      lateCancellations: (data['lateCancellations'] as num?)?.toInt() ?? 0,
      noShows: (data['noShows'] as num?)?.toInt() ?? 0,
      attendedMatches: (data['attendedMatches'] as num?)?.toInt() ?? 0,
      lastReliabilityUpdateAt: _readNullableDate(
        data['lastReliabilityUpdateAt'],
      ),
      lastAbilityRatingAt: _readNullableDate(data['lastAbilityRatingAt']),
      matchesPlayed:
          (data['matchesPlayed'] as num?)?.toInt() ??
          (data['completedMatches'] as num?)?.toInt() ??
          0,
      rating:
          (data['rating'] as num?)?.toDouble() ??
          (data['abilityRating'] as num?)?.toDouble() ??
          3.0,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'age': age,
      'location': location,
      'preferredPosition': preferredPosition,
      'secondaryPosition': secondaryPosition,
      'skillLevel': skillLevel,
      'favouriteFoot': favouriteFoot,
      'bio': bio,
      'photoUrl': photoUrl,
      'reliabilityScore': reliabilityScore,
      'abilityRating': abilityRating,
      'abilityRatingCount': abilityRatingCount,
      'completedMatches': completedMatches,
      'cancelledMatches': cancelledMatches,
      'lateCancellations': lateCancellations,
      'noShows': noShows,
      'attendedMatches': attendedMatches,
      'lastReliabilityUpdateAt': lastReliabilityUpdateAt == null
          ? null
          : Timestamp.fromDate(lastReliabilityUpdateAt!),
      'lastAbilityRatingAt': lastAbilityRatingAt == null
          ? null
          : Timestamp.fromDate(lastAbilityRatingAt!),
      'matchesPlayed': matchesPlayed,
      'rating': abilityRating,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppUser copyWith({
    String? fullName,
    String? email,
    int? age,
    String? location,
    String? preferredPosition,
    String? secondaryPosition,
    String? skillLevel,
    String? favouriteFoot,
    String? bio,
    String? photoUrl,
    int? reliabilityScore,
    double? abilityRating,
    int? abilityRatingCount,
    int? completedMatches,
    int? cancelledMatches,
    int? lateCancellations,
    int? noShows,
    int? attendedMatches,
    DateTime? lastReliabilityUpdateAt,
    DateTime? lastAbilityRatingAt,
    int? matchesPlayed,
    double? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      age: age ?? this.age,
      location: location ?? this.location,
      preferredPosition: preferredPosition ?? this.preferredPosition,
      secondaryPosition: secondaryPosition ?? this.secondaryPosition,
      skillLevel: skillLevel ?? this.skillLevel,
      favouriteFoot: favouriteFoot ?? this.favouriteFoot,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      reliabilityScore: reliabilityScore ?? this.reliabilityScore,
      abilityRating: abilityRating ?? this.abilityRating,
      abilityRatingCount: abilityRatingCount ?? this.abilityRatingCount,
      completedMatches: completedMatches ?? this.completedMatches,
      cancelledMatches: cancelledMatches ?? this.cancelledMatches,
      lateCancellations: lateCancellations ?? this.lateCancellations,
      noShows: noShows ?? this.noShows,
      attendedMatches: attendedMatches ?? this.attendedMatches,
      lastReliabilityUpdateAt:
          lastReliabilityUpdateAt ?? this.lastReliabilityUpdateAt,
      lastAbilityRatingAt: lastAbilityRatingAt ?? this.lastAbilityRatingAt,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      rating: rating ?? abilityRating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
