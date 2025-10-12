import 'package:flutter_test/flutter_test.dart';
import 'package:mytrademate/services/exchange_rules.dart';

void main() {
  test(
      'tiny step keeps precision; zero/negative step is no-op; midpoint rounds up',
      () {
    expect(roundQtyToStepForTest(0.00000009, 0.00000001), 0.00000009);
    expect(roundQtyToStepForTest(1.2345, 0.0), 1.2345);
    expect(roundQtyToStepForTest(1.2345, -0.001), 1.2345);
    expect(roundQtyToStepForTest(1.005, 0.01), 1.01);
    expect(roundQtyToStepForTest(1.0049, 0.01), 1.00);
    expect(roundQtyToStepForTest(1.006, 0.01), 1.01);
  });
}
