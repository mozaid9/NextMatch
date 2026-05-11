import 'package:cloud_firestore/cloud_firestore.dart';

class FootballMatch {
  const FootballMatch({
    required this.id,
    required this.title,
    required this.organiserId,
    required this.organiserName,
    required this.locationName,
    required this.address,
    required this.date,
    required this.startTime,
    required this.startDateTime,
    required this.durationMinutes,
    required this.format,
    required this.totalPlayersNeeded,
    required this.joinedPlayerCount,
    required this.pricePerPlayer,
    required this.skillLevel,
    required this.pitchType,
    required this.description,
    required this.neededPositions,
    required this.visibility,
    required this.status,
    required this.cancellationPolicy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String organiserId;
  final String organiserName;
  final String locationName;
  final String address;
  final DateTime date;
  final String startTime;
  final DateTime startDateTime;
  final int durationMinutes;
  final String format;
  final int totalPlayersNeeded;
  final int joinedPlayerCount;
  final double pricePerPlayer;
  final String skillLevel;
  final String pitchType;
  final String description;
  final Map<String, int> neededPositions;
  final String visibility;
  final String status;
  final String cancellationPolicy;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFull => joinedPlayerCount >= totalPlayersNeeded;
  bool get isNearlyFull =>
      !isFull && totalPlayersNeeded - joinedPlayerCount <= 2;
  String get spacesLabel => '$joinedPlayerCount/$totalPlayersNeeded';
  String get displayStatus =>
      isFull ? 'Full' : (isNearlyFull ? 'Nearly Full' : status);

  factory FootballMatch.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return FootballMatch.fromMap(data, document.id);
  }

  factory FootballMatch.fromMap(Map<String, dynamic> data, String id) {
    return FootballMatch(
      id: data['id'] as String? ?? id,
      title: data['title'] as String? ?? '',
      organiserId: data['organiserId'] as String? ?? '',
      organiserName: data['organiserName'] as String? ?? '',
      locationName: data['locationName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      date: _readDate(data['date']),
      startTime: data['startTime'] as String? ?? '',
      startDateTime: _readDate(data['startDateTime']),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 60,
      format: data['format'] as String? ?? '5-a-side',
      totalPlayersNeeded: (data['totalPlayersNeeded'] as num?)?.toInt() ?? 10,
      joinedPlayerCount: (data['joinedPlayerCount'] as num?)?.toInt() ?? 0,
      pricePerPlayer: (data['pricePerPlayer'] as num?)?.toDouble() ?? 0,
      skillLevel: data['skillLevel'] as String? ?? 'Casual',
      pitchType: data['pitchType'] as String? ?? 'Astro',
      description: data['description'] as String? ?? '',
      neededPositions: _readNeededPositions(data['neededPositions']),
      visibility: data['visibility'] as String? ?? 'Public',
      status: data['status'] as String? ?? 'Open',
      cancellationPolicy: data['cancellationPolicy'] as String? ?? '',
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'organiserId': organiserId,
      'organiserName': organiserName,
      'locationName': locationName,
      'address': address,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'durationMinutes': durationMinutes,
      'format': format,
      'totalPlayersNeeded': totalPlayersNeeded,
      'joinedPlayerCount': joinedPlayerCount,
      'pricePerPlayer': pricePerPlayer,
      'skillLevel': skillLevel,
      'pitchType': pitchType,
      'description': description,
      'neededPositions': neededPositions,
      'visibility': visibility,
      'status': status,
      'cancellationPolicy': cancellationPolicy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FootballMatch copyWith({
    String? id,
    String? title,
    String? organiserId,
    String? organiserName,
    String? locationName,
    String? address,
    DateTime? date,
    String? startTime,
    DateTime? startDateTime,
    int? durationMinutes,
    String? format,
    int? totalPlayersNeeded,
    int? joinedPlayerCount,
    double? pricePerPlayer,
    String? skillLevel,
    String? pitchType,
    String? description,
    Map<String, int>? neededPositions,
    String? visibility,
    String? status,
    String? cancellationPolicy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FootballMatch(
      id: id ?? this.id,
      title: title ?? this.title,
      organiserId: organiserId ?? this.organiserId,
      organiserName: organiserName ?? this.organiserName,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      startDateTime: startDateTime ?? this.startDateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      format: format ?? this.format,
      totalPlayersNeeded: totalPlayersNeeded ?? this.totalPlayersNeeded,
      joinedPlayerCount: joinedPlayerCount ?? this.joinedPlayerCount,
      pricePerPlayer: pricePerPlayer ?? this.pricePerPlayer,
      skillLevel: skillLevel ?? this.skillLevel,
      pitchType: pitchType ?? this.pitchType,
      description: description ?? this.description,
      neededPositions: neededPositions ?? this.neededPositions,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String statusForCount(int joinedPlayerCount, int totalPlayersNeeded) {
    if (joinedPlayerCount >= totalPlayersNeeded) return 'Full';
    if (totalPlayersNeeded - joinedPlayerCount <= 2) return 'Nearly Full';
    return 'Open';
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static Map<String, int> _readNeededPositions(dynamic value) {
    if (value is! Map) {
      return {
        'Goalkeepers': 0,
        'Defenders': 0,
        'Midfielders': 0,
        'Forwards': 0,
      };
    }

    return value.map(
      (key, dynamic mapValue) =>
          MapEntry(key.toString(), (mapValue as num?)?.toInt() ?? 0),
    );
  }
}
