import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('tiny tick sizes and negative/zero behave as expected', () {
    // very small tick keeps precision
    expect(roundPriceToTickForTest(100.00000009, 0.00000001), 100.00000009);

    // zero/negative tick => no-op
    expect(roundPriceToTickForTest(101.23, 0.0), 101.23);
    expect(roundPriceToTickForTest(101.23, -0.01), 101.23);

    // exact midpoint rounds up
    // 100.025 / 0.05 = 2000.5 => 2001 * 0.05 = 100.05
    expect(roundPriceToTickForTest(100.025, 0.05), closeTo(100.05, 1e-9));

    // below midpoint rounds down
    expect(roundPriceToTickForTest(100.0249, 0.05), 100.00);

    // above midpoint rounds up
    expect(roundPriceToTickForTest(100.026, 0.05), closeTo(100.05, 1e-9));
  });
}


