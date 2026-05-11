import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../viewmodels/payment_viewmodel.dart';

class MockPaymentScreen extends StatelessWidget {
  const MockPaymentScreen({
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColours.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColours.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.title, style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      '${match.locationName} - $position',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _PaymentRow(
                label: 'Match fee',
                value: CurrencyHelpers.formatGBP(match.pricePerPlayer),
              ),
              _PaymentRow(
                label: 'Platform fee placeholder',
                value: CurrencyHelpers.formatGBP(platformFee),
              ),
              const Divider(color: AppColours.line, height: 28),
              _PaymentRow(
                label: 'Total',
                value: CurrencyHelpers.formatGBP(total),
                isTotal: true,
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColours.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColours.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card, color: AppColours.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mock payment method', style: AppTextStyles.h3),
                          const SizedBox(height: 4),
                          Text(
                            'Stripe PaymentIntents will replace this step.',
                            style: AppTextStyles.bodyMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (paymentViewModel.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  paymentViewModel.errorMessage!,
                  style: AppTextStyles.bodyMuted.copyWith(
                    color: AppColours.error,
                  ),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Pay and Secure Spot',
                icon: Icons.lock,
                isLoading: paymentViewModel.isLoading,
                onPressed: () async {
                  final success = await paymentViewModel.payAndJoin(
                    match: match,
                    user: currentUser,
                    position: position,
                  );

                  if (!context.mounted || !success) return;
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
