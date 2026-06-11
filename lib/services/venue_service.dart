import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/venue.dart';

class VenueService {
  VenueService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _venues =>
      _firestore.collection('venues');

  CollectionReference<Map<String, dynamic>> _favouritesFor(String uid) =>
      _firestore.collection('users').doc(uid).collection('favouriteVenues');

  Stream<Set<String>> favouriteVenueIdsStream(String uid) {
    return _favouritesFor(uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.id).toSet());
  }

  Future<void> toggleFavouriteVenue({
    required String uid,
    required Venue venue,
  }) async {
    final ref = _favouritesFor(uid).doc(venue.id);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'venueId': venue.id,
        'name': venue.name,
        'city': venue.city,
        'savedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  Stream<List<Venue>> venuesStream({String? city}) {
    Query<Map<String, dynamic>> query = _venues;
    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs.map(Venue.fromFirestore).toList(),
        );
  }

  Future<Venue?> getVenue(String id) async {
    final snapshot = await _venues.doc(id).get();
    if (!snapshot.exists) return null;
    return Venue.fromFirestore(snapshot);
  }

  /// Computes the bookable slots for a venue on a given day. Slots are 1-hour
  /// blocks from the venue's `openingHour` up to (but not including) its
  /// `closingHour`, generated per pitch.
  ///
  /// In a real implementation `isAvailable` would be derived from a `bookings`
  /// sub-collection; for now everything is shown as available.
  List<VenueSlot> generateSlotsForDay(Venue venue, DateTime day) {
    final slots = <VenueSlot>[];
    final dayStart = DateTime(day.year, day.month, day.day);
    for (final pitch in venue.pitches) {
      for (var hour = venue.openingHour; hour < venue.closingHour; hour++) {
        final start = dayStart.add(Duration(hours: hour));
        slots.add(VenueSlot(
          startTime: start,
          pitch: pitch,
          isAvailable: !start.isBefore(DateTime.now()),
        ));
      }
    }
    return slots;
  }
}
