import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('roundPriceToTickForTest rounds to nearest tick', () {
    expect(roundPriceToTickForTest(100.04, 0.05), closeTo(100.05, 1e-9));
    expect(roundPriceToTickForTest(100.02, 0.05), closeTo(100.00, 1e-9));
    expect(roundPriceToTickForTest(100.025, 0.01), closeTo(100.03, 1e-9));
  });

  test('roundQtyToStepForTest rounds to nearest step', () {
    expect(roundQtyToStepForTest(0.123456, 0.001), closeTo(0.123, 1e-9));
    expect(roundQtyToStepForTest(1.49, 0.1), closeTo(1.5, 1e-9));
    expect(roundQtyToStepForTest(1.44, 0.1), closeTo(1.4, 1e-9));
  });

  test('clampMinNotionalForTest increases qty just enough', () {
    final q1 = clampMinNotionalForTest(qty: 0.0009, price: 10000, minNotional: 10);
    expect(q1 * 10000, greaterThanOrEqualTo(10));
    final q2 = clampMinNotionalForTest(qty: 0.002, price: 10000, minNotional: 10);
    expect(q2, closeTo(0.002, 1e-12));
  });
}


