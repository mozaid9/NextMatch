import 'package:intl/intl.dart';

class CurrencyHelpers {
  const CurrencyHelpers._();

  static final NumberFormat _gbpFormatter = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
  );

  static String formatGBP(num amount) => _gbpFormatter.format(amount);

  static double roundMoney(num amount) =>
      double.parse(amount.toStringAsFixed(2));

  /// Display-side mirror of the authoritative fee in functions/index.js
  /// (SERVICE_FEE_RATE / SERVICE_FEE_MIN_PENCE) — keep the two in sync.
  static double serviceFee(num amount) {
    final calculated = (amount * 100 * 0.06).roundToDouble();
    final pence = calculated < 50 ? 50.0 : calculated;
    return roundMoney(pence / 100);
  }
}
