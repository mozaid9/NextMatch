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

  static double mockPlatformFee(num amount) {
    final calculated = amount * 0.06;
    final capped = calculated.clamp(0.35, 1.25);
    return roundMoney(capped);
  }
}
