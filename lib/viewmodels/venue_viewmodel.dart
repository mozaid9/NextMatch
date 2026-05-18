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

  Future<bool> seedDemoVenues() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _venueService.seedDemoVenues();
      return true;
    } catch (error) {
      errorMessage = 'Could not seed demo venues.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
