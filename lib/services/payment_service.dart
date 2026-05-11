import '../core/utils/currency_helpers.dart';
import '../models/app_user.dart';
import '../models/football_match.dart';
import 'match_service.dart';

class PaymentService {
  PaymentService(this._matchService);

  final MatchService _matchService;

  double platformFeeFor(FootballMatch match) {
    return CurrencyHelpers.mockPlatformFee(match.pricePerPlayer);
  }

  double totalFor(FootballMatch match) {
    return CurrencyHelpers.roundMoney(
      match.pricePerPlayer + platformFeeFor(match),
    );
  }

  Future<void> mockPayAndJoin({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    // TODO(Stripe): Replace this delay with PaymentIntent creation, confirmation
    // and webhook-backed fulfilment in Cloud Functions.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    await _matchService.confirmMockPaymentAndJoin(
      match: match,
      user: user,
      position: position,
    );
  }
}
