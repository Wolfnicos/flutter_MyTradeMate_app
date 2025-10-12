import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test('binary tick sizes round correctly (nearest with .5 up)', () {
    // tick 0.125
    expect(roundPriceToTickForTest(100.187, 0.125),
        100.125); // below midpoint -> down
    expect(roundPriceToTickForTest(100.1875, 0.125), 100.25); // exact .5 -> up
    expect(roundPriceToTickForTest(100.238, 0.125),
        100.25); // above midpoint -> up

    // tick 0.0625
    expect(roundPriceToTickForTest(10.031, 0.0625), 10.0); // below midpoint
    expect(
        roundPriceToTickForTest(10.03125, 0.0625), 10.0625); // exact .5 -> up
    expect(roundPriceToTickForTest(10.055, 0.0625), 10.0625); // above midpoint
  });
}
