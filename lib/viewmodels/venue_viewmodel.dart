import 'package:flutter/foundation.dart';

import '../models/venue.dart';
import '../services/venue_service.dart';

class VenueViewModel extends ChangeNotifier {
  VenueViewModel(this._venueService);

  final VenueService _venueService;

  bool isLoading = false;
  String? errorMessage;

  Stream<List<Venue>> venuesStream({String? city}) =>
      _venueService.venuesStream(city: city);

  Future<Venue?> getVenue(String id) => _venueService.getVenue(id);

  List<VenueSlot> generateSlotsForDay(Venue venue, DateTime day) =>
      _venueService.generateSlotsForDay(venue, day);

  Stream<Set<String>> favouriteVenueIdsStream(String uid) =>
      _venueService.favouriteVenueIdsStream(uid);

  Future<void> toggleFavouriteVenue({
    required String uid,
    required Venue venue,
  }) =>
      _venueService.toggleFavouriteVenue(uid: uid, venue: venue);
}
