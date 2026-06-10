import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colours.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/currency_helpers.dart';
import '../../core/widgets/primary_button.dart';
import '../../models/app_user.dart';
import '../../models/football_match.dart';
import '../../viewmodels/payment_viewmodel.dart';

enum _PayMethod { applePay, card }

class MockPaymentScreen extends StatefulWidget {
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
  State<MockPaymentScreen> createState() => _MockPaymentScreenState();
}

class _MockPaymentScreenState extends State<MockPaymentScreen> {
  _PayMethod _method = _PayMethod.card;
  final _cardFormKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    super.dispose();
  }

  String? _validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter a card number';
    if (digits.length < 13 || digits.length > 19) {
      return 'Card number looks wrong';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    final raw = (value ?? '').trim();
    final match = RegExp(r'^(0[1-9]|1[0-2])\s*/\s*(\d{2})$').firstMatch(raw);
    if (match == null) return 'Use MM / YY';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final now = DateTime.now();
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59);
    if (endOfMonth.isBefore(now)) return 'Card has expired';
    return null;
  }

  String? _validateCvc(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 3 || digits.length > 4) return '3–4 digits';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final paymentViewModel = context.watch<PaymentViewModel>();
    final platformFee = paymentViewModel.platformFeeFor(widget.match);
    final total = paymentViewModel.totalFor(widget.match);

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
                        Text(widget.match.title, style: AppTextStyles.h3),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.match.locationName} · ${widget.position}',
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
              value: CurrencyHelpers.formatGBP(widget.match.pricePerPlayer),
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

            // Payment method
            Text('Payment method', style: AppTextStyles.h3),
            const SizedBox(height: 12),

            // Apple Pay
            _MethodTile(
              selected: _method == _PayMethod.applePay,
              onTap: () => setState(() => _method = _PayMethod.applePay),
              dark: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apple, color: Colors.white, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    'Apple Pay',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Divider between methods
            Row(
              children: [
                const Expanded(child: Divider(color: AppColours.line)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: AppTextStyles.small),
                ),
                const Expanded(child: Divider(color: AppColours.line)),
              ],
            ),
            const SizedBox(height: 10),

            // Card
            _MethodTile(
              selected: _method == _PayMethod.card,
              onTap: () => setState(() => _method = _PayMethod.card),
              dark: false,
              child: Row(
                children: [
                  const Icon(Icons.credit_card_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Debit / Credit card',
                      style: AppTextStyles.body,
                    ),
                  ),
                  // Mock card brand logos
                  _CardLogo(icon: Icons.credit_card, label: 'VISA'),
                  const SizedBox(width: 6),
                  _CardLogo(icon: Icons.credit_card, label: 'MC'),
                ],
              ),
            ),

            // Card fields (shown when card selected)
            if (_method == _PayMethod.card) ...[
              const SizedBox(height: 10),
              Form(
                key: _cardFormKey,
                child: Column(
                  children: [
                    _CardField(
                      controller: _cardNumberController,
                      hint: 'Card number',
                      icon: Icons.credit_card_outlined,
                      keyboardType: TextInputType.number,
                      validator: _validateCardNumber,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _CardField(
                            controller: _expiryController,
                            hint: 'MM / YY',
                            keyboardType: TextInputType.datetime,
                            validator: _validateExpiry,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CardField(
                            controller: _cvcController,
                            hint: 'CVC',
                            icon: Icons.lock_outline,
                            keyboardType: TextInputType.number,
                            obscure: true,
                            validator: _validateCvc,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (paymentViewModel.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                paymentViewModel.errorMessage!,
                style: AppTextStyles.small.copyWith(color: AppColours.error),
              ),
            ],

            const SizedBox(height: 28),

            // Pay button
            PrimaryButton(
              label: _method == _PayMethod.applePay
                  ? 'Pay with Apple Pay'
                  : 'Pay ${CurrencyHelpers.formatGBP(total)}',
              icon: _method == _PayMethod.applePay
                  ? Icons.apple
                  : Icons.lock_outline,
              isLoading: paymentViewModel.isLoading,
              onPressed: () async {
                if (_method == _PayMethod.card &&
                    _cardFormKey.currentState?.validate() != true) {
                  return;
                }
                final success = await paymentViewModel.payAndJoin(
                  match: widget.match,
                  user: widget.currentUser,
                  position: widget.position,
                );
                if (!context.mounted || !success) return;
                Navigator.of(context).pop(true);
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
                  'Test mode — no real payment is taken',
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

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.selected,
    required this.onTap,
    required this.child,
    required this.dark,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: dark
              ? const Color(0xFF1A1A1A)
              : selected
              ? AppColours.accent.withValues(alpha: 0.08)
              : AppColours.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: dark
                ? selected
                      ? AppColours.accent
                      : Colors.transparent
                : selected
                ? AppColours.accent
                : AppColours.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _CardField extends StatelessWidget {
  const _CardField({
    required this.controller,
    required this.hint,
    required this.validator,
    this.icon,
    this.keyboardType,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?) validator;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscure,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        suffixIcon: icon == null
            ? null
            : Icon(icon, size: 16, color: AppColours.mutedText),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 16,
        ),
      ),
    );
  }
}

class _CardLogo extends StatelessWidget {
  const _CardLogo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColours.cardAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColours.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColours.mutedText,
          letterSpacing: 0.5,
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
