import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../core/utils/currency_helpers.dart';
import '../models/app_user.dart';
import '../models/football_match.dart';
import 'match_service.dart';

class PaymentService {
  PaymentService(this._matchService);

  final MatchService _matchService;

  double platformFeeFor(FootballMatch match) {
    return CurrencyHelpers.serviceFee(match.pricePerPlayer);
  }

  double totalFor(FootballMatch match) {
    return CurrencyHelpers.roundMoney(
      match.pricePerPlayer + platformFeeFor(match),
    );
  }

  Future<void> freeJoin({
    required FootballMatch match,
    required AppUser user,
    required String position,
  }) async {
    await _matchService.freeJoinMatch(
      match: match,
      user: user,
      position: position,
    );
  }

  /// Asks the backend for a Stripe Checkout URL. The amount is computed
  /// server-side from the match document — the client only says which match.
  Future<Uri> createStripeCheckoutUrl({
    required FootballMatch match,
    required String position,
  }) async {
    if (!kIsWeb) {
      throw Exception(
        'Card payments are web-only for now — open NextMatch in a browser.',
      );
    }
    final origin = Uri.base.origin;
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west2',
    ).httpsCallable('createStripeCheckout');

    final result = await callable.call<dynamic>({
      'matchId': match.id,
      'position': position,
      'successUrl': '$origin/?checkout=success&matchId=${match.id}',
      'cancelUrl': '$origin/?checkout=cancelled&matchId=${match.id}',
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    final url = data['url'] as String? ?? '';
    if (url.isEmpty) {
      throw Exception('Stripe did not return a checkout link.');
    }
    return Uri.parse(url);
  }
}
