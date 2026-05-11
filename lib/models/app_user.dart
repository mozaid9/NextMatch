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
    this.matchesPlayed = 0,
    this.rating = 0,
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
  final int matchesPlayed;
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
      matchesPlayed: (data['matchesPlayed'] as num?)?.toInt() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
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
      'matchesPlayed': matchesPlayed,
      'rating': rating,
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
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
