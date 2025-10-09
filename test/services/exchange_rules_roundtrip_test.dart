import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('round price/qty then clamp notional meets threshold', () {
    final price = roundPriceToTickForTest(20123.437, 0.1); // → ~20123.4/20123.5
    var qty = roundQtyToStepForTest(0.00093, 0.00001); // → 0.00093
    qty = clampMinNotionalForTest(qty: qty, price: price, minNotional: 10);
    expect(qty * price, greaterThanOrEqualTo(10));
  });
}


