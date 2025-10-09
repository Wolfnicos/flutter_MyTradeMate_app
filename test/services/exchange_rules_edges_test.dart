import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('roundPrice/Qty no-op when step/tick ≤ 0', () {
    expect(roundPriceToTickForTest(101.23, 0), 101.23);
    expect(roundQtyToStepForTest(0.12345, -0.1), 0.12345);
  });

  test('clampMinNotionalForTest increases qty minimally', () {
    final q =
        clampMinNotionalForTest(qty: 0.0009, price: 10000, minNotional: 10);
    expect(q * 10000, greaterThanOrEqualTo(10));
  });
}


