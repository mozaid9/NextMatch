import 'package:cloud_firestore/cloud_firestore.dart';

/// A bookable football venue (partnered facility with pitches for hire).
class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.description,
    required this.photoUrl,
    required this.amenities,
    required this.pitches,
    required this.openingHour,
    required this.closingHour,
    required this.rating,
    required this.reviewCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String description;
  final String photoUrl;
  final List<String> amenities;
  final List<VenuePitch> pitches;
  /// 24h clock — earliest bookable slot start (e.g. 8 for 8am).
  final int openingHour;
  /// 24h clock — latest bookable slot start (e.g. 22 for 10pm).
  final int closingHour;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;

  /// Lowest hourly rate across all pitch types at this venue.
  double get fromPrice {
    if (pitches.isEmpty) return 0;
    return pitches.map((p) => p.pricePerHour).reduce((a, b) => a < b ? a : b);
  }

  /// Distinct pitch types available (e.g. ["5-a-side", "7-a-side"]).
  List<String> get pitchTypes =>
      pitches.map((p) => p.format).toSet().toList()..sort();

  factory Venue.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return Venue.fromMap(data, document.id);
  }

  factory Venue.fromMap(Map<String, dynamic> data, String id) {
    return Venue(
      id: data['id'] as String? ?? id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      city: data['city'] as String? ?? '',
      description: data['description'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      amenities: (data['amenities'] as List?)?.cast<String>() ?? const [],
      pitches: (data['pitches'] as List?)
              ?.map((p) => VenuePitch.fromMap(p as Map<String, dynamic>))
              .toList() ??
          const [],
      openingHour: (data['openingHour'] as num?)?.toInt() ?? 8,
      closingHour: (data['closingHour'] as num?)?.toInt() ?? 22,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: _readDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'description': description,
        'photoUrl': photoUrl,
        'amenities': amenities,
        'pitches': pitches.map((p) => p.toMap()).toList(),
        'openingHour': openingHour,
        'closingHour': closingHour,
        'rating': rating,
        'reviewCount': reviewCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}

class VenuePitch {
  const VenuePitch({
    required this.id,
    required this.format,
    required this.surface,
    required this.capacity,
    required this.pricePerHour,
  });

  final String id;
  /// e.g. "5-a-side", "7-a-side", "11-a-side"
  final String format;
  /// e.g. "Astroturf", "3G", "Grass", "Indoor"
  final String surface;
  final int capacity;
  final double pricePerHour;

  factory VenuePitch.fromMap(Map<String, dynamic> data) {
    return VenuePitch(
      id: data['id'] as String? ?? '',
      format: data['format'] as String? ?? '5-a-side',
      surface: data['surface'] as String? ?? 'Astroturf',
      capacity: (data['capacity'] as num?)?.toInt() ?? 10,
      pricePerHour: (data['pricePerHour'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'format': format,
        'surface': surface,
        'capacity': capacity,
        'pricePerHour': pricePerHour,
      };
}

/// A bookable hour-long slot at a specific pitch.
class VenueSlot {
  const VenueSlot({
    required this.startTime,
    required this.pitch,
    required this.isAvailable,
  });

  final DateTime startTime;
  final VenuePitch pitch;
  final bool isAvailable;

  DateTime get endTime => startTime.add(const Duration(hours: 1));
}
