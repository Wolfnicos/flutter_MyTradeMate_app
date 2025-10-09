import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test(
      'roundPriceToTickForTest handles very large values and scientific-like cases',
      () {
    // very large value + large tick → round to nearest multiple
    // 1_000_000.25 / 0.5 = 2_000_000.5 -> up => 1_000_000.5
    expect(roundPriceToTickForTest(1000000.25, 0.5), 1000000.5);

    // large tick, just below midpoint → down
    // 1_000_000.24 / 0.5 = 2_000_000.48 -> down => 1_000_000.0
    expect(roundPriceToTickForTest(1000000.24, 0.5), 1000000.0);

    // scientific-like: emulate huge values without parser
    // 1e8 + 0.06 with tick 0.1 -> 100_000_000.1
    expect(roundPriceToTickForTest(100000000.06, 0.1), 100000000.1);

    // value much larger than tick step (exact multiple stays)
    expect(roundPriceToTickForTest(100000000.0, 1000.0), 100000000.0);
  });
}



