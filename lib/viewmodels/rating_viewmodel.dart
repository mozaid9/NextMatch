import 'package:flutter/foundation.dart';

import '../services/rating_service.dart';

class RatingViewModel extends ChangeNotifier {
  RatingViewModel(this._ratingService);

  final RatingService _ratingService;

  bool isLoading = false;
  String? errorMessage;

  Future<bool> submitRatings({
    required String matchId,
    required String ratedByUserId,
    required Map<String, double> ratingsByUserId,
    String? comment,
  }) async {
    if (ratingsByUserId.isEmpty) {
      errorMessage = 'Rate at least one player before submitting.';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      for (final entry in ratingsByUserId.entries) {
        await _ratingService.submitPlayerRating(
          matchId: matchId,
          ratedUserId: entry.key,
          ratedByUserId: ratedByUserId,
          rating: entry.value,
          comment: comment,
        );
      }
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
