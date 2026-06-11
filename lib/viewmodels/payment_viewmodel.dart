import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/football_match.dart';
import '../services/payment_service.dart';

class PaymentViewModel extends ChangeNotifier {
  PaymentViewModel(this._paymentService);

  final PaymentService _paymentService;

  bool isLoading = false;
  String? errorMessage;

  double platformFeeFor(FootballMatch match) =>
      _paymentService.platformFeeFor(match);

  double totalFor(FootballMatch match) => _paymentService.totalFor(match);

  Future<bool> freeJoin({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _paymentService.freeJoin(
        match: match,
        user: user,
        position: position,
      );
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the Stripe Checkout URL to redirect to, or null on failure
  /// (with errorMessage set).
  Future<Uri?> createStripeCheckout({
    required FootballMatch match,
    required String position,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      return await _paymentService.createStripeCheckoutUrl(
        match: match,
        position: position,
      );
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> payAndJoin({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _paymentService.mockPayAndJoin(
        match: match,
        user: user,
        position: position,
      );
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
