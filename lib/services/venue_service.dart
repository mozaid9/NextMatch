import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/venue.dart';

class VenueService {
  VenueService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _uuid = Uuid();

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

  /// Seeds a handful of demo venues so users can explore the flow before
  /// real venue onboarding happens.
  Future<void> seedDemoVenues() async {
    final existing = await _venues.limit(1).get();
    if (existing.docs.isNotEmpty) {
      // Already seeded.
      return;
    }

    final now = DateTime.now();
    final venues = [
      Venue(
        id: _uuid.v4(),
        name: 'Powerleague Bolton',
        address: '52 Manchester Rd, Bolton',
        city: 'Bolton',
        description:
            'Four floodlit 3G pitches with full changing facilities and on-site parking.',
        photoUrl: '',
        amenities: const [
          'Floodlights',
          'Parking',
          'Changing rooms',
          'Showers',
          'Vending',
        ],
        pitches: [
          VenuePitch(
            id: _uuid.v4(),
            format: '5-a-side',
            surface: '3G',
            capacity: 10,
            pricePerHour: 60,
          ),
          VenuePitch(
            id: _uuid.v4(),
            format: '7-a-side',
            surface: '3G',
            capacity: 14,
            pricePerHour: 85,
          ),
        ],
        openingHour: 8,
        closingHour: 22,
        rating: 4.5,
        reviewCount: 128,
        createdAt: now,
      ),
      Venue(
        id: _uuid.v4(),
        name: 'Goals Manchester',
        address: '38 Whitworth Park, Manchester',
        city: 'Manchester',
        description:
            'Premium 5 and 7-a-side pitches with bar, café and free WiFi.',
        photoUrl: '',
        amenities: const [
          'Floodlights',
          'Parking',
          'Bar',
          'Café',
          'WiFi',
          'Changing rooms',
        ],
        pitches: [
          VenuePitch(
            id: _uuid.v4(),
            format: '5-a-side',
            surface: 'Astroturf',
            capacity: 10,
            pricePerHour: 55,
          ),
          VenuePitch(
            id: _uuid.v4(),
            format: '7-a-side',
            surface: 'Astroturf',
            capacity: 14,
            pricePerHour: 80,
          ),
          VenuePitch(
            id: _uuid.v4(),
            format: '11-a-side',
            surface: 'Grass',
            capacity: 22,
            pricePerHour: 140,
          ),
        ],
        openingHour: 9,
        closingHour: 23,
        rating: 4.7,
        reviewCount: 245,
        createdAt: now,
      ),
      Venue(
        id: _uuid.v4(),
        name: 'Soccerdome Salford',
        address: 'Trafford Way, Salford',
        city: 'Salford',
        description:
            'Indoor and outdoor pitches, open late, perfect for after-work games.',
        photoUrl: '',
        amenities: const [
          'Indoor',
          'Floodlights',
          'Parking',
          'Vending',
        ],
        pitches: [
          VenuePitch(
            id: _uuid.v4(),
            format: '5-a-side',
            surface: 'Indoor',
            capacity: 10,
            pricePerHour: 50,
          ),
          VenuePitch(
            id: _uuid.v4(),
            format: '5-a-side',
            surface: 'Astroturf',
            capacity: 10,
            pricePerHour: 45,
          ),
        ],
        openingHour: 7,
        closingHour: 23,
        rating: 4.2,
        reviewCount: 67,
        createdAt: now,
      ),
    ];

    final batch = _firestore.batch();
    for (final venue in venues) {
      batch.set(_venues.doc(venue.id), venue.toMap());
    }
    await batch.commit();
  }
}
