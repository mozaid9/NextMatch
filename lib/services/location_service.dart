class LocationService {
  Future<void> initialise() async {
    // TODO(Google Maps): Request permissions and initialise Maps SDK support.
  }

  Future<List<String>> nearbyLocationSuggestions(String query) async {
    // TODO(Google Maps): Replace text locations with geocoded venue search.
    return query.trim().isEmpty ? const [] : [query.trim()];
  }
}
