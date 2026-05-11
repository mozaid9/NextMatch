import 'package:flutter_test/flutter_test.dart';
import 'package:next_match/core/utils/currency_helpers.dart';

void main() {
  test('formats GBP prices for match cards and payment screens', () {
    expect(CurrencyHelpers.formatGBP(6.5), '£6.50');
  });
}
