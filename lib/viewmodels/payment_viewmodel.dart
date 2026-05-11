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
