import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../viewmodels/payment_viewmodel.dart';

/// Collects payment for a match share via Stripe's hosted checkout.
/// The charge itself is priced and confirmed server-side; this screen
/// only shows the breakdown and hands the player to Stripe.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({
    super.key,
    required this.match,
    required this.currentUser,
    required this.position,
  });

  final FootballMatch match;
  final AppUser currentUser;
  final String position;

  @override
  Widget build(BuildContext context) {
    final paymentViewModel = context.watch<PaymentViewModel>();
    final platformFee = paymentViewModel.platformFeeFor(match);
    final total = paymentViewModel.totalFor(match);

    return Scaffold(
      appBar: AppBar(title: const Text('Secure your spot')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            // Match summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColours.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColours.line),
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: AppColours.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.sports_soccer,
                      color: AppColours.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(match.title, style: AppTextStyles.h3),
                        const SizedBox(height: 2),
                        Text(
                          '${match.locationName} · $position',
                          style: AppTextStyles.small,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Price breakdown
            _PriceRow(
              label: 'Match fee',
              value: CurrencyHelpers.formatGBP(match.pricePerPlayer),
            ),
            _PriceRow(
              label: 'Service fee',
              value: CurrencyHelpers.formatGBP(platformFee),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(color: AppColours.line),
            ),
            _PriceRow(
              label: 'Total',
              value: CurrencyHelpers.formatGBP(total),
              isTotal: true,
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColours.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColours.line),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: AppColours.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "You'll be redirected to Stripe's secure checkout to "
                      'pay by card, Apple Pay or Google Pay.',
                      style: AppTextStyles.small,
                    ),
                  ),
                ],
              ),
            ),

            if (paymentViewModel.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                paymentViewModel.errorMessage!,
                style: AppTextStyles.small.copyWith(color: AppColours.error),
              ),
            ],

            const SizedBox(height: 28),

            PrimaryButton(
              label: 'Pay ${CurrencyHelpers.formatGBP(total)} securely',
              icon: Icons.lock_outline,
              isLoading: paymentViewModel.isLoading,
              onPressed: () async {
                final url = await paymentViewModel.createStripeCheckout(
                  match: match,
                  position: position,
                );
                if (url == null) return;
                await launchUrl(url, webOnlyWindowName: '_self');
              },
            ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.science_outlined,
                  size: 12,
                  color: AppColours.mutedText,
                ),
                const SizedBox(width: 4),
                Text(
                  'Stripe test mode, use card 4242 4242 4242 4242',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: isTotal ? AppTextStyles.h3 : AppTextStyles.bodyMuted,
            ),
          ),
          Text(
            value,
            style: isTotal
                ? AppTextStyles.h3.copyWith(color: AppColours.accent)
                : AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
